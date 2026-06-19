## P3.5 production Clusterer test. Proves the concept, the pure in-memory
## algorithm, and the DB-backed pipeline (signatures -> LSH bands in SQLite ->
## candidates -> assign cluster_ids).
## Run: nim c --threads:on -r tests/test_clustering.nim

import std/[unittest, os, sets, options, tables, sequtils]
import tiny_sqlite
import ../src/qh/types
import ../src/qh/concepts
import ../src/qh/storage/[database, feed_store, cluster_store]
import ../src/qh/clustering/[engine, clusterer]

static:
  doAssert(NimClusterer is Clusterer)

proc similarAppleItems(): seq[ClusteringItem] =
  @[ClusteringItem(id: 1, title: "Apple announces the new M4 chip for MacBooks", feedId: 1, feedUrl: "https://arstechnica.com"),
    ClusteringItem(id: 2, title: "Apple unveils the new M4 chip for MacBooks", feedId: 2, feedUrl: "https://theverge.com"),
    ClusteringItem(id: 3, title: "NASA confirms date for next Artemis moon launch", feedId: 3, feedUrl: "https://nasa.gov")]

suite "production clusterer (P3.5)":
  test "pure cluster: syndicated pair clusters, unrelated singleton":
    let c = newNimClusterer()
    let r = c.cluster(similarAppleItems())
    check r.isOk
    check r.clusters.len == 1                   # one multi-member cluster
    for rep, members in pairs(r.clusters):
      check members.len == 2
      check members.contains(1'i64)
      check members.contains(2'i64)
    check 3 notin r.clusters                    # Artemis stays singleton

  test "DB pipeline: assigns cluster_ids + stores LSH bands":
    let path = getTempDir() / "qh_nim_cluster.db"
    removeFile(path)
    let db = openAndCreate(path)
    defer:
      db.close()
      removeFile(path); removeFile(path & "-wal"); removeFile(path & "-shm")
    let fs = SqliteFeedStore(db: db)
    let cs = SqliteClusterStore(db: db)

    # Insert two feeds, each with one near-identical "Apple M4" item.
    discard fs.upsertWithItems(FeedData(
      title: "Ars", url: "https://arstechnica.com/feed", siteLink: "https://arstechnica.com",
      items: @[Item(title: "Apple announces the new M4 chip for MacBooks",
                    link: "https://arstechnica.com/a", pubDate: "2026-01-01 00:00:00")]))
    discard fs.upsertWithItems(FeedData(
      title: "Verge", url: "https://theverge.com/feed", siteLink: "https://theverge.com",
      items: @[Item(title: "Apple unveils the new M4 chip for MacBooks",
                    link: "https://theverge.com/b", pubDate: "2026-01-01 00:00:00")]))

    # Load the stored items as ClusteringItems.
    var items: seq[ClusteringItem]
    for r in db.all("""
      SELECT i.id, i.title, f.id, f.url FROM items i JOIN feeds f ON i.feed_id = f.id"""):
      items.add ClusteringItem(id: r[0].intVal, title: r[1].strVal,
                               feedId: r[2].intVal, feedUrl: r[3].strVal)
    check items.len == 2

    # Run the DB-backed pipeline.
    let c = newNimClusterer()
    let res = c.runClusteringPipeline(cs, items)
    check res.isOk
    check res.clusters.len == 1

    # cluster_ids were assigned to both items (same cluster).
    let cIds = db.all("SELECT cluster_id FROM items ORDER BY id").mapIt(
      if it[0].kind == sqliteInteger: it[0].intVal else: 0'i64)
    check cIds[0] != 0 and cIds[1] != 0
    check cIds[0] == cIds[1]

    # LSH bands were stored.
    let bandCount = db.one("SELECT COUNT(*) FROM lsh_bands").get[0].intVal
    check bandCount > 0
    echo "  pipeline: clusters=", res.clusters.len, " lsh_bands=", bandCount
