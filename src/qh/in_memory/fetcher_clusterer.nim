## In-memory test impls for the Fetcher and Clusterer boundaries.
##
## InMemoryFetcher returns canned FeedData (no HTTP). InMemoryClusterer uses a
## simple deterministic overlap-grouping (NOT MinHash) so tests are stable and
## fast; the real MinHash/LSH Clusterer lives in spike/clustering_vertical.nim
## and will move into production in Phase 3.

import std/[tables, sets, strutils, sequtils]
import ../types

# ---------------------------------------------------------------- Fetcher

type
  InMemoryFetcher* = ref object
    canned*: Table[string, FeedData]     ## url -> data
    failNext*: bool

proc fetch*(f: InMemoryFetcher, url: string): FetchResult =
  if f.failNext: return errFetch(feNetwork)
  if url in f.canned: okFetch(f.canned[url])
  else: errFetch(feHttp)

# ---------------------------------------------------------------- Clusterer (deterministic, test-only)

proc normalize(text: string): seq[string] =
  text.toLowerAscii().splitWhitespace()

proc overlap(a, b: HashSet[string]): float =
  if a.card == 0 or b.card == 0: return 0.0
  let inter = a * b
  inter.card.float / min(a.card, b.card).float

type
  InMemoryClusterer* = ref object
    threshold*: float

proc cluster*(c: InMemoryClusterer, items: seq[ClusteringItem]): ClusterResult =
  if items.len == 0: return errCluster(ceNoInput)
  # Pre-compute word sets; O(n^2) is fine for a test impl.
  var ws: Table[int64, HashSet[string]]
  for it in items: ws[it.id] = toHashSet(normalize(it.title))
  var groups: Table[int64, seq[int64]]   # root id -> members
  var parent: Table[int64, int64]
  for it in items: parent[it.id] = it.id
  proc find(p: var Table[int64,int64], x: int64): int64 =
    result = x
    while p[result] != result: result = p[result]
  for i in 0..<items.len:
    for j in (i+1)..<items.len:
      let a = items[i]; let b = items[j]
      if a.feedId == b.feedId: continue
      if overlap(ws[a.id], ws[b.id]) >= c.threshold:
        let (ra, rb) = (find(parent, a.id), find(parent, b.id))
        if ra != rb:
          if ra < rb: parent[rb] = ra else: parent[ra] = rb
  for it in items:
    let root = find(parent, it.id)
    groups.mgetOrPut(root, @[]).add(it.id)
  var outc: Cluster
  for members in groups.values:
    if members.len > 1:
      let rep = min(members)
      outc[rep] = members
  okCluster(outc)
