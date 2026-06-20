## Production SQLite FeedStore - port of src/repositories/feed_repository.cr.
## Satisfies the FeedStore concept (upsertFeed / listFeeds). Also provides
## upsertWithItems, the core write path used by the fetcher pipeline. Sole
## importer of tiny_sqlite alongside the other storage modules.

import std/[times, os, options]
import tiny_sqlite
import ../types
import ./url_normalizer
import ./database  # dbStr

const DbTimeFormat* = "yyyy-MM-dd HH:mm:ss"   # Constants::DB_TIME_FORMAT (SQLite stores strings)

type
  SqliteFeedStore* = ref object
    db*: DbConn

proc nowUtcStr(): string = now().utc().format(DbTimeFormat)
# NOTE: missing item fields are stored as '' (empty string), not SQL NULL.
# Crystal stores nil -> NULL here. tiny_sqlite's exec varargs[DbValue, toDbValue]
# rejects a bare DbValue, so passing NULL needs a prepared-statement path; that
# is a P3.3 follow-up. Empty-string is a minor deviation, harmless for queries
# that test IS NULL via COALESCE.

proc upsertFeed*(s: SqliteFeedStore; f: FeedRow): StoreUnitResult =
  ## Insert-or-update a feed row by url. Returns okStore / errStore.
  try:
    let existing = s.db.one("SELECT id FROM feeds WHERE url = ?", f.url)
    if existing.isSome:
      let id = existing.get[0].intVal
      s.db.exec("""
        UPDATE feeds SET title=?, site_link=?, favicon=?, favicon_data=?,
                          header_color=?, header_text_color=?, last_fetched=?
        WHERE id=?""",
        f.title, f.siteLink, f.favicon, f.faviconData, f.headerColor,
        f.headerTextColor, nowUtcStr(), id)
    else:
      s.db.exec("""
        INSERT INTO feeds (url, title, site_link, favicon, favicon_data,
                           header_color, header_text_color, last_fetched)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        f.url, f.title, f.siteLink, f.favicon, f.faviconData, f.headerColor,
        f.headerTextColor, nowUtcStr())
    okStore()
  except CatchableError:
    errStore(seIo)

proc listFeeds*(s: SqliteFeedStore): FeedListResult =
  try:
    var rows: seq[FeedRow]
    for r in s.db.all("""
      SELECT id, url, title, site_link, favicon, favicon_data,
             header_color, header_text_color
      FROM feeds ORDER BY id"""):
      rows.add FeedRow(
        id: r[0].intVal, url: r[1].strVal, title: r[2].strVal,
        siteLink: r[3].dbStr, favicon: r[4].dbStr, faviconData: r[5].dbStr,
        headerColor: r[6].dbStr, headerTextColor: r[7].dbStr)
    okFeeds(rows)
  except CatchableError:
    errFeeds(seIo)

proc countItems*(s: SqliteFeedStore; feedId: int64): int =
  ## Item count for one feed (production batches this - P1 #7).
  let r = s.db.one("SELECT COUNT(*) FROM items WHERE feed_id = ?", feedId)
  if r.isSome: r.get[0].intVal.int else: 0

proc recentItems*(s: SqliteFeedStore; feedId: int64; limit = 30): seq[Item] =
  ## Most-recent items for a feed (port of find_with_items item read).
  const Q = "SELECT title, link, pub_date, COALESCE(version,''), COALESCE(comment_url,''), COALESCE(commentary_url,'') FROM items WHERE feed_id = ? AND (pub_date IS NULL OR pub_date <= datetime('now','+1 day')) ORDER BY COALESCE(pub_date,'1970-01-01 00:00:00') DESC, id DESC LIMIT ?"
  for r in s.db.all(Q, feedId, limit):
    result.add Item(title: r[0].dbStr, link: r[1].dbStr, pubDate: r[2].dbStr,
                    version: r[3].dbStr, commentUrl: r[4].dbStr,
                    commentaryUrl: r[5].dbStr)

proc feedsMissingFavicon*(s: SqliteFeedStore; limit = 1): seq[(int64, string, string)] =
  ## Feeds whose favicon is empty OR whose favicon file is missing on disk
  ## (stale path from a previous run where favicons/ was cleared).
  ## Returns (id, site_link, url). Fetches limit*3 candidates to skip ones that
  ## already have a valid cached file. ORDER BY RANDOM() to avoid getting stuck
  ## retrying the same stubborn feed every tick.
  for r in s.db.all("SELECT id, COALESCE(site_link,''), url, COALESCE(favicon,'') FROM feeds ORDER BY RANDOM() LIMIT ?", limit * 3):
    let fav = r[3].dbStr
    let missing = fav.len == 0 or (fav.len > 10 and not fileExists("favicons" / fav[10..^1]))
    if missing:
      result.add((r[0].intVal, r[1].dbStr, r[2].dbStr))
      if result.len >= limit: break

proc setFavicon*(s: SqliteFeedStore; feedId: int64; path: string) =
  s.db.exec("UPDATE feeds SET favicon = ? WHERE id = ?", path, feedId)

proc feedIdForUrl(s: SqliteFeedStore; url: string): int64 =
  let r = s.db.one("SELECT id FROM feeds WHERE url = ?", url)
  if r.isSome: r.get[0].intVal else: 0'i64

proc upsertWithItems*(s: SqliteFeedStore; fd: FeedData): StoreUnitResult =
  ## Port of upsert_with_items: upsert the feed, then insert/dedup its items
  ## in one transaction. Normalizes each item link for the UNIQUE constraint.
  try:
    s.db.exec("BEGIN")
    discard s.upsertFeed(FeedRow(
      url: fd.url, title: fd.title, siteLink: fd.siteLink,
      headerColor: fd.headerColor, headerTextColor: fd.headerTextColor,
      favicon: fd.favicon))
    let feedId = s.feedIdForUrl(fd.url)
    if feedId == 0:
      s.db.exec("ROLLBACK")
      return errStore(seNotFound)
    for it in fd.items:
      s.db.exec("""
        INSERT INTO items (feed_id, title, link, normalized_link, pub_date,
                           version, comment_url, commentary_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(feed_id, normalized_link) DO UPDATE SET
          title=excluded.title, link=excluded.link, pub_date=excluded.pub_date,
          version=excluded.version, comment_url=excluded.comment_url,
          commentary_url=excluded.commentary_url""",
        feedId, it.title, it.link, normalizeUrl(it.link), it.pubDate,
        it.version, it.commentUrl, it.commentaryUrl)
    s.db.exec("COMMIT")
    okStore()
  except CatchableError:
    try: s.db.exec("ROLLBACK") except CatchableError: discard
    errStore(seIo)
