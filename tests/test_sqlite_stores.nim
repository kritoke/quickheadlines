## P3.3 production SQLite stores test. Builds a temp DB, exercises the three
## stores end-to-end, and proves each satisfies its concept.
## Run: nim c -r tests/test_sqlite_stores.nim

import std/[unittest, os, sets, tables, options, times]
import tiny_sqlite
import ../src/qh/types
import ../src/qh/concepts
import ../src/qh/storage/database
import ../src/qh/storage/feed_store
import ../src/qh/storage/item_store
import ../src/qh/storage/cluster_store

# Compile-time: production SQLite impls satisfy their black-box concepts.
static:
  doAssert(SqliteFeedStore is FeedStore)
  doAssert(SqliteItemStore is ItemStore)
  doAssert(SqliteClusterStore is ClusterStore)

proc itemIds(db: DbConn): seq[int64] =
  for r in db.all("SELECT id FROM items ORDER BY id"): result.add r[0].intVal

suite "SQLite stores (P3.3)":
  test "feed upsert + list + items + timeline + clusters":
    let path = getTempDir() / "qh_nim_stores.db"
    removeFile(path)
    let db = openAndCreate(path)
    defer:
      db.close()
      removeFile(path); removeFile(path & "-wal"); removeFile(path & "-shm")

    let feedStore = SqliteFeedStore(db: db)
    let itemStore = SqliteItemStore(db: db)
    let cs = SqliteClusterStore(db: db)

    # Upsert a feed with two items (dedup on normalized_link).
    # Item pub_dates relative to the real clock (the timeline query filters
    # pub_date <= datetime('now','+1 day'); hardcoded future dates would be excluded).
    let nowStr = now().utc().format("yyyy-MM-dd HH:mm:ss")
    let earlier = (now().utc() - initDuration(hours = 2)).format("yyyy-MM-dd HH:mm:ss")
    let latest   = (now().utc() - initDuration(hours = 1)).format("yyyy-MM-dd HH:mm:ss")
    let upsert = feedStore.upsertWithItems(FeedData(
      title: "Example", url: "https://example.com/feed", siteLink: "https://example.com",
      items: @[
        Item(title: "Story A", link: "https://example.com/a", pubDate: earlier),
        Item(title: "Story B", link: "https://example.com/b", pubDate: latest),
        Item(title: "Story A dup", link: "https://example.com/a?utm_source=test", pubDate: earlier),  # dedups onto A
      ]))
    check upsert.isOk
    discard nowStr

    # listFeeds.
    let listed = feedStore.listFeeds()
    check listed.isOk and listed.feeds.len == 1
    check listed.feeds[0].url == "https://example.com/feed"

    # Dedup: 3 items inserted but Story A dup normalizes to /a -> 2 rows.
    let ids = db.itemIds()
    check ids.len == 2

    # Timeline returns both, ordered DESC by pub_date.
    let tl = itemStore.findTimeline(limit = 10, offset = 0, daysBack = 0)
    check tl.isOk
    check tl.total == 2
    check tl.entries[0].title == "Story B"   # later pub_date first

    # Cluster the two items together; clearClusters undoes it.
    var clusters: Cluster
    clusters[ids[0]] = @[ids[0], ids[1]]
    let assign = cs.assignClusters(clusters)
    check assign.isOk
    check db.one("SELECT cluster_id FROM items WHERE id=?", ids[1]).get[0].intVal == ids[0]
    let clear = cs.clearClusters()
    check clear.isOk
    check db.one("SELECT COUNT(*) FROM items WHERE cluster_id IS NOT NULL").get[0].intVal == 0

  test "LSH band store + find candidates":
    let path = getTempDir() / "qh_nim_lsh.db"
    removeFile(path)
    let db = openAndCreate(path)
    defer:
      db.close()
      removeFile(path); removeFile(path & "-wal"); removeFile(path & "-shm")
    db.exec("INSERT INTO feeds (url,title,site_link,last_fetched) VALUES ('u','t','s','x')")
    let feedId = db.one("SELECT last_insert_rowid()").get[0].intVal
    db.exec("INSERT INTO items (feed_id,title,link,normalized_link,pub_date) VALUES (?,?,?,?, '2026-06-19 10:00:00')",
      feedId, "t", "l", "l")
    let itemId = db.one("SELECT last_insert_rowid()").get[0].intVal

    let cs = SqliteClusterStore(db: db)
    cs.storeLshBands(itemId, @["deadbeef", "cafef00d"])
    let cands = cs.findLshCandidates(@[(0, "deadbeef")])
    check cands.card == 1
    check cands.contains(itemId)
    let miss = cs.findLshCandidates(@[(1, "notthere")])
    check miss.card == 0
