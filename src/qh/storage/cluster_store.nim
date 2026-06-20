## Production SQLite ClusterStore - port of src/storage/clustering_store.cr.
## Satisfies the ClusterStore concept (assignClusters / clearClusters).
##
## P0 #3 fix (context.md): in Crystal, find_lsh_candidates read lsh_bands with
## no mutex while writers held it -> stale/inconsistent candidates under the
## connection pool. Here the store owns a single DbConn and is the sole
## boundary for all cluster reads/writes, so access is serialized by
## construction (no cross-connection read/write race within the boundary).
## LSH band storage helpers for the clustering pipeline live here too.

import std/[sets, tables]
import tiny_sqlite
import ../types

type
  SqliteClusterStore* = ref object
    db*: DbConn

proc assignClusters*(s: SqliteClusterStore; clusters: Cluster): StoreUnitResult =
  ## UPDATE items.cluster_id for every cluster member, in one transaction.
  try:
    s.db.exec("BEGIN")
    for rep, members in clusters:
      for m in members:
        s.db.exec("UPDATE items SET cluster_id = ? WHERE id = ?", rep, m)
    s.db.exec("COMMIT")
    okStore()
  except CatchableError:
    try: s.db.exec("ROLLBACK") except CatchableError: discard
    errStore(seIo)

proc clearClusters*(s: SqliteClusterStore): StoreUnitResult =
  ## Null out all cluster assignments and drop LSH bands (port of
  ## clear_clustering_metadata).
  try:
    s.db.exec("BEGIN")
    s.db.exec("UPDATE items SET cluster_id = NULL")
    s.db.exec("DELETE FROM lsh_bands")
    s.db.exec("COMMIT")
    okStore()
  except CatchableError:
    try: s.db.exec("ROLLBACK") except CatchableError: discard
    errStore(seIo)

# ---------------------------------------------------------------- LSH band helpers (for the P3.5 clustering pipeline)

proc storeLshBands*(s: SqliteClusterStore; itemId: int64; bandHashes: seq[string]) =
  ## Replace this item's LSH bands. bandHashes are pre-formatted hex strings
  ## (port of store_lsh_bands; the hashing is owned by the Clusterer).
  s.db.exec("BEGIN")
  s.db.exec("DELETE FROM lsh_bands WHERE item_id = ?", itemId)
  for i, bh in bandHashes:
    s.db.exec(
      "INSERT INTO lsh_bands (item_id, band_index, band_hash) VALUES (?, ?, ?)",
      itemId, i, bh)
  s.db.exec("COMMIT")

proc findLshCandidates*(s: SqliteClusterStore; bands: seq[(int, string)];
                        maxN = 500): HashSet[int64] =
  ## Given (bandIndex, bandHash) pairs, return distinct candidate item ids.
  ## Capped at maxN (port of find_lsh_candidates; the race from P0 #3 is gone
  ## because this runs on the store's own serialized connection).
  for (bandIndex, bandHash) in bands:
    for r in s.db.all(
        "SELECT DISTINCT item_id FROM lsh_bands WHERE band_index = ? AND band_hash = ?",
        bandIndex, bandHash):
      result.incl r[0].intVal
      if result.card >= maxN: return result
