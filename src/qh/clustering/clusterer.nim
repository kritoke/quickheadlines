## Production Clusterer - satisfies the Clusterer concept (design D4).
##
## `NimClusterer.cluster` is pure (MinHash + in-memory LSH candidate pairs +
## overlap verify + Union-Find) and matches the Phase-1 spike algorithm.
## `runClusteringPipeline` is the DB-backed full pipeline used by the refresh
## supervisor: signatures -> ClusterStore.storeLshBands -> ClusterStore
## .findLshCandidates -> verify -> Union-Find -> ClusterStore.assignClusters.
##
## Default bands/rows/threshold mirror Crystal ClusteringConfig defaults.

import std/[sets, tables, sequtils]
import ../types
import ../storage/cluster_store
import ./engine

const
  DefaultBands* = 20
  DefaultRows* = 6           # numHashes = 120
  DefaultThreshold* = 0.35

proc findSimilarPairsInMemory(items: seq[ClusteringItem];
                               threshold: float; bands, rows: int): seq[(int64, int64)] =
  ## Bucket signatures by band hash -> candidate pairs -> overlap verify.
  let numHashes = bands * rows
  var sigs: Table[int64, seq[uint32]]
  var words: Table[int64, HashSet[string]]
  var byId: Table[int64, ClusteringItem]
  for it in items:
    if not canCluster(it.title): continue
    sigs[it.id] = minhashSignature(it.title, numHashes)
    words[it.id] = wordSet(it.title)
    byId[it.id] = it
  # bucket by (bandIndex, hexHash)
  var buckets: Table[(int, string), seq[int64]]
  for id, sig in pairs(sigs):
    for (bi, bh) in bandHashes(sig, bands, rows):
      buckets.mgetOrPut((bi, bh), @[]).add(id)
  var seen: HashSet[(int64, int64)]
  for ids in buckets.values:
    if ids.len < 2: continue
    for a in 0..<ids.len:
      for b in (a+1)..<ids.len:
        let (x, y) = (ids[a], ids[b])
        let key = if x < y: (x, y) else: (y, x)
        if key in seen: continue
        seen.incl(key)
        let ia = byId[x]; let ib = byId[y]
        if ia.feedId == ib.feedId: continue          # same-feed dedup
        if sameBaseDomain(ia.feedUrl, ib.feedUrl): continue
        if overlapCoefficient(words[x], words[y]) >= threshold:
          result.add(key)

type
  NimClusterer* = ref object
    threshold*: float
    bands*: int
    rows*: int

proc newNimClusterer*(threshold = DefaultThreshold; bands = DefaultBands;
                      rows = DefaultRows): NimClusterer =
  NimClusterer(threshold: threshold, bands: bands, rows: rows)

proc cluster*(c: NimClusterer; items: seq[ClusteringItem]): ClusterResult =
  ## Pure (concept-satisfying) cluster: in-memory MinHash/LSH -> ClusterResult.
  if items.len == 0: return errCluster(ceNoInput)
  let pairs = findSimilarPairsInMemory(items, c.threshold, c.bands, c.rows)
  let ids = items.filterIt(canCluster(it.title)).mapIt(it.id)
  okCluster(buildClustersFromPairs(pairs, ids))

# ---------------------------------------------------------------- DB-backed pipeline

proc runClusteringPipeline*(c: NimClusterer; store: SqliteClusterStore;
                            items: seq[ClusteringItem]): ClusterResult =
  ## Full pipeline with persistence. Stores LSH bands, finds candidates from
  ## the DB, verifies, Union-Finds, and assigns cluster_ids via the store.
  ## Returns the same ClusterResult the pure clusterer would, and the DB now
  ## reflects the assignments + bands.
  if items.len == 0: return errCluster(ceNoInput)
  let numHashes = c.bands * c.rows
  var sigs: Table[int64, seq[uint32]]
  var words: Table[int64, HashSet[string]]
  var byId: Table[int64, ClusteringItem]
  for it in items:
    if not canCluster(it.title): continue
    sigs[it.id] = minhashSignature(it.title, numHashes)
    words[it.id] = wordSet(it.title)
    byId[it.id] = it
    let bands = bandHashes(sigs[it.id], c.bands, c.rows)
    store.storeLshBands(it.id, bands.mapIt(it[1]))   # hex hashes only

  var seen: HashSet[(int64, int64)]
  var pairs: seq[(int64, int64)]
  for id, sig in pairs(sigs):
    let candidates = store.findLshCandidates(bandHashes(sig, c.bands, c.rows))
    for cand in candidates:
      if cand == id or cand notin byId: continue
      let key = if id < cand: (id, cand) else: (cand, id)
      if key in seen: continue
      seen.incl(key)
      let ia = byId[id]; let ib = byId[cand]
      if ia.feedId == ib.feedId: continue
      if sameBaseDomain(ia.feedUrl, ib.feedUrl): continue
      if overlapCoefficient(words[id], words[cand]) >= c.threshold:
        pairs.add(key)

  let ids = toSeq(byId.keys)
  let clusters = buildClustersFromPairs(pairs, ids)
  discard store.assignClusters(clusters)
  okCluster(clusters)
