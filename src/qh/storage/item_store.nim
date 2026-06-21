## Production SQLite ItemStore - port of src/repositories/story_repository.cr.
## Satisfies the ItemStore concept (findTimeline). The timeline query is the
## cluster_info CTE + JOINs, faithfully ported (COUNT(*) OVER() carries the
## total so the expensive CTE runs once, not twice - addresses P1 #8).

import std/[times, sequtils, strutils, tables]
import tiny_sqlite
import ../types
import ./feed_store   # DbTimeFormat
import ./database     # dbStr

type
  SqliteItemStore* = ref object
    db*: DbConn

proc intOrZero(v: DbValue): int64 =
  if v.kind == sqliteInteger: v.intVal else: 0'i64

proc cutoffStr(daysBack: int): string =
  ## Earliest pub_date to include. daysBack<=0 means "all" (epoch floor).
  if daysBack > 0: (now().utc() - initDuration(days = daysBack)).format(DbTimeFormat)
  else: "1970-01-01 00:00:00"

proc findTimeline*(s: SqliteItemStore; limit, offset: int;
                   daysBack: int; allowedFeedUrls: seq[string] = @[]): TimelineResult =
  ## Port of StoryRepository.find_timeline_items. Returns entries + total.
  ## When allowedFeedUrls is non-empty, only items from those feeds are returned
  ## (tab filtering). The IN clause is built inline (trusted config URLs).
  try:
    let cutoff = cutoffStr(daysBack)
    let feedFilter = if allowedFeedUrls.len > 0:
      " AND f.url IN (" & allowedFeedUrls.mapIt("'" & it.replace("'", "''") & "'").join(",") & ")"
    else: ""
    var entries: seq[TimelineEntry]
    var total = 0
    let q = """
      WITH cluster_info AS (
        SELECT cluster_id, MIN(id) AS representative_id, COUNT(*) AS cluster_size
        FROM items WHERE cluster_id IS NOT NULL AND pub_date >= ? GROUP BY cluster_id
      )
      SELECT i.id, i.title, i.link, i.pub_date,
             f.title, f.url, f.site_link, f.favicon, f.favicon_data,
             f.header_color, f.header_text_color, i.cluster_id,
             CASE WHEN i.cluster_id IS NULL OR i.id = ci.representative_id THEN 1 ELSE 0 END,
             COALESCE(ci.cluster_size, 0), i.comment_url, i.commentary_url,
             COUNT(*) OVER()
      FROM items i JOIN feeds f ON i.feed_id = f.id
      LEFT JOIN cluster_info ci ON i.cluster_id = ci.cluster_id
      WHERE (i.pub_date IS NULL OR i.pub_date <= datetime('now','+1 day'))
        AND (i.cluster_id IS NULL OR i.id = ci.representative_id)
        AND i.pub_date >= ?""" & feedFilter & """
      ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
      LIMIT ? OFFSET ?"""
    for r in s.db.all(q, cutoff, cutoff, limit, offset):
      total = r[16].intOrZero().int
      entries.add TimelineEntry(
        id: r[0].intOrZero(), title: r[1].dbStr, link: r[2].dbStr,
        pubDate: r[3].dbStr, feedTitle: r[4].dbStr, feedUrl: r[5].dbStr,
        feedLink: r[6].dbStr, favicon: r[7].dbStr,
        headerColor: r[9].dbStr, headerTextColor: r[10].dbStr,
        clusterId: r[11].intOrZero(),
        representative: r[12].intOrZero() == 1,
        clusterSize: r[13].intOrZero().int,
        commentUrl: r[14].dbStr)
    okTimeline(entries, total)
  except CatchableError:
    errTimeline(seIo)

proc loadUnclusteredItems*(s: SqliteItemStore; limit = 500): seq[ClusteringItem] =
  ## Items whose cluster_id IS NULL, newest first. Used by the clustering
  ## supervisor to find items that need clustering.
  for r in s.db.all("""
    SELECT i.id, i.title, f.id, f.url
    FROM items i JOIN feeds f ON i.feed_id = f.id
    WHERE i.cluster_id IS NULL
      AND (i.pub_date IS NULL OR i.pub_date <= datetime('now','+1 day'))
      AND (i.pub_date IS NULL OR i.pub_date >= datetime('now', '-' || '30' || ' days'))
    ORDER BY i.id DESC LIMIT ?""", limit):
    result.add ClusteringItem(id: r[0].intVal, title: r[1].dbStr,
                              feedId: r[2].intVal, feedUrl: r[3].dbStr)

proc loadAllClusters*(s: SqliteItemStore): Table[int64, seq[TimelineEntry]] =
  ## Load all clustered items grouped by cluster_id (port of /api/clusters query).
  for r in s.db.all("""
    SELECT i.id, i.title, i.link, i.pub_date,
           f.title, f.url, f.site_link, f.favicon, f.favicon_data,
           f.header_color, f.header_text_color, i.cluster_id,
           CASE WHEN i.id = (SELECT MIN(id) FROM items WHERE cluster_id = i.cluster_id) THEN 1 ELSE 0 END,
           (SELECT COUNT(*) FROM items WHERE cluster_id = i.cluster_id),
           COALESCE(i.comment_url,''), COALESCE(i.commentary_url,'')
    FROM items i JOIN feeds f ON i.feed_id = f.id
    WHERE i.cluster_id IS NOT NULL
    ORDER BY i.cluster_id, i.id"""):
    let cid = r[11].intOrZero()
    let entry = TimelineEntry(
      id: r[0].intOrZero(), title: r[1].dbStr, link: r[2].dbStr,
      pubDate: r[3].dbStr, feedTitle: r[4].dbStr, feedUrl: r[5].dbStr,
      feedLink: r[6].dbStr, favicon: r[7].dbStr,
      headerColor: r[9].dbStr, headerTextColor: r[10].dbStr,
      clusterId: cid, representative: r[12].intOrZero() == 1,
      clusterSize: r[13].intOrZero().int, commentUrl: r[14].dbStr)
    result.mgetOrPut(cid, @[]).add(entry)

proc feedItems*(s: SqliteItemStore; feedUrl: string;
                limit, offset: int): TimelineResult =
  ## Items for a specific feed URL with pagination (port of /api/feed_more).
  try:
    var entries: seq[TimelineEntry]
    var total = 0
    for r in s.db.all("""
      SELECT i.id, i.title, i.link, i.pub_date,
             f.title, f.url, f.site_link, f.favicon, f.favicon_data,
             f.header_color, f.header_text_color,
             0, 1, 0, COALESCE(i.comment_url,''), COALESCE(i.commentary_url,''),
             COUNT(*) OVER()
      FROM items i JOIN feeds f ON i.feed_id = f.id
      WHERE f.url = ?
        AND (i.pub_date IS NULL OR i.pub_date <= datetime('now','+1 day'))
      ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
      LIMIT ? OFFSET ?""", feedUrl, limit, offset):
      total = r[16].intOrZero().int
      entries.add TimelineEntry(
        id: r[0].intOrZero(), title: r[1].dbStr, link: r[2].dbStr,
        pubDate: r[3].dbStr, feedTitle: r[4].dbStr, feedUrl: r[5].dbStr,
        feedLink: r[6].dbStr, favicon: r[7].dbStr,
        headerColor: r[9].dbStr, headerTextColor: r[10].dbStr,
        clusterId: r[11].intOrZero(),
        representative: r[12].intOrZero() == 1,
        clusterSize: r[13].intOrZero().int,
        commentUrl: r[14].dbStr)
    okTimeline(entries, total)
  except CatchableError:
    errTimeline(seIo)
