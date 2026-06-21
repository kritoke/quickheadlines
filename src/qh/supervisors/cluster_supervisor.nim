## Clustering supervisor - periodic background job that assigns cluster IDs to
## unclustered items using the production Clusterer + ClusterStore. Each tick
## loads unclustered items, runs the MinHash/LSH pipeline, assigns cluster IDs.
## Runs in its own thread with its own DbConn; WAL coexists with the server's
## reads. Sets dirty so the SPA gets a WS push when clusters change.

import std/[os, atomics, tables]
import ../types
import ../storage/[database, item_store, cluster_store]
import ../clustering/clusterer

type
  ClusterArgs = object
    dbPath: string
    threshold: float
    bands: int
    rows: int
    maxItems: int
    intervalSec: int
    dirty: ref Atomic[bool]
    shuttingDown: ptr Atomic[bool]

proc clusterLoop(a: ClusterArgs) {.thread.} =
  {.cast(gcsafe).}:
    let db = openAndCreate(a.dbPath)
    let itemStore = SqliteItemStore(db: db)
    let clusterStore = SqliteClusterStore(db: db)
    let clusterer = newNimClusterer(a.threshold, a.bands, a.rows)
    while true:
      if a.shuttingDown != nil and a.shuttingDown[].load():
        echo "[cluster] shutting down"
        break
      let items = itemStore.loadUnclusteredItems(a.maxItems)
      if items.len > 0:
        let res = clusterer.runClusteringPipeline(clusterStore, items)
        if res.isOk and res.clusters.len > 0:
          a.dirty[].store(true)
          echo "[cluster] clustered ", items.len, " items into ", res.clusters.len, " groups"
      if a.intervalSec <= 0: break
      for _ in 0 ..< a.intervalSec:
        if a.shuttingDown != nil and a.shuttingDown[].load(): break
        sleep(1000)
    closeDb(db)

proc startClusterSupervisor*(dbPath: string; threshold = 0.35;
                             bands = 20; rows = 6; maxItems = 500;
                             intervalSec = 3600;
                             dirty: ref Atomic[bool] = nil;
                             shuttingDown: ptr Atomic[bool] = nil): Thread[ClusterArgs] =
  createThread(result, clusterLoop,
               ClusterArgs(dbPath: dbPath, threshold: threshold,
                           bands: bands, rows: rows, maxItems: maxItems,
                           intervalSec: intervalSec, dirty: dirty,
                           shuttingDown: shuttingDown))
