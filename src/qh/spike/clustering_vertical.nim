## Phase-1 clustering vertical spike (tasks 1.2).
##
## Ports the Crystal clustering engine (src/services/clustering_engine.cr, on
## lexis-minhash + prismatiq) to Nim behind a documented Clusterer boundary.
## Validates: MinHash signatures, LSH banding, Union-Find, overlap-coefficient
## verification, same-feed / same-domain dedup - i.e. the algorithm ports.
##
## Scope note: exact byte-equality of cluster IDs with the Crystal backend
## (exit criterion 1.2.3) requires matching lexis-minhash's hash functions on
## FROZEN fixtures; that is a Phase-2 deliverable. This spike uses a standard
## salted MinHash and validates functional correctness (similar headlines
## cluster together, dissimilar do not).
##
## Run: nim c -r src/qh/spike/clustering_vertical.nim

import std/[hashes, sets, tables, strutils, sequtils, algorithm, uri]

# ---------------------------------------------------------------- domain

type
  ClusteringItem* = object
    id*: int64
    title*: string
    feedId*: int64
    feedUrl*: string

  ## Clusterer boundary (design D4). Returns a map of representative id ->
  ## member ids. Documented interface (concepts can't enforce generic returns
  ## on Nim 2.2.4 - see fetch_vertical.nim finding).
  ClusterResult* = Table[int64, seq[int64]]

# ---------------------------------------------------------------- text helpers (ported from Crystal)

const StopWords* = [
  "the","a","an","and","or","but","in","on","at","to","for","of","with","by",
  "from","as","is","was","are","were","been","be","have","has","had","do",
  "does","did","will","would","could","should","may","might","must","shall",
  "can","need","this","that","these","those","it","time","times","day","days",
  "week","weeks","month","months","year","years","says","said","just","now",
  "how","what","when","why","building","built","build","using","via","get",
  "got","new","make","making","way","use","youre","your","works","work",
  "working","today"
]

proc normalizeHeadline*(text: string): string =
  if text.len == 0: return ""
  let words = text.toLowerAscii().strip().splitWhitespace()
  words.filterIt(it notin StopWords).join(" ")

proc wordSet*(text: string): HashSet[string] =
  toHashSet(normalizeHeadline(text).splitWhitespace())

proc overlapCoefficient*(a, b: HashSet[string]): float =
  if a.card == 0 or b.card == 0: return 0.0
  let inter = a * b
  if inter.card == 0: return 0.0
  inter.card.float / min(a.card, b.card).float

proc canCluster*(title: string; minWords = 4): bool =
  title.len > 0 and normalizeHeadline(title).splitWhitespace().len >= minWords

# ---------------------------------------------------------------- domain dedup (ported)

proc extractBaseDomain*(url: string): string =
  if url.len == 0: return ""
  try:
    let host = parseUri(url).hostname
    if host.len == 0: return ""
    result = host.toLowerAscii()
    for pre in ["feeds.", "rss.", "feed.", "www."]:
      if result.startsWith(pre): result = result[pre.len..^1]
  except CatchableError:
    result = ""

proc sameBaseDomain*(u1, u2: string): bool =
  if u1.len == 0 or u2.len == 0: return false
  extractBaseDomain(u1) == extractBaseDomain(u2)

# ---------------------------------------------------------------- MinHash signature

## Standard MinHash over salted word hashes. numHashes = bands * rows.
proc minhashSignature*(title: string, numHashes: int): seq[uint32] =
  result = newSeq[uint32](numHashes)
  for i in 0..<numHashes: result[i] = high(uint32)
  for w in normalizeHeadline(title).splitWhitespace():
    for i in 0..<numHashes:
      let h = uint32(hash(w & "#" & $i))   # salted independent hash
      if h < result[i]: result[i] = h

# ---------------------------------------------------------------- Union-Find (ported)

type UnionFind* = object
  parent: Table[int64, int64]

proc initUnionFind*(): UnionFind = UnionFind()

proc find*(uf: var UnionFind, x: int64): int64 =
  if x notin uf.parent: uf.parent[x] = x
  result = x
  while uf.parent[result] != result: result = uf.parent[result]
  var cur = x
  while uf.parent[cur] != result:        # path compression
    let nxt = uf.parent[cur]
    uf.parent[cur] = result
    cur = nxt

proc union*(uf: var UnionFind, a, b: int64) =
  let (ra, rb) = (uf.find(a), uf.find(b))
  if ra == rb: return
  if ra < rb: uf.parent[rb] = ra else: uf.parent[ra] = rb  # smaller id wins

# ---------------------------------------------------------------- LSH candidate pairs

proc lshCandidates*(sigs: Table[int64, seq[uint32]], bands, rows: int): seq[(int64, int64)] =
  ## Items sharing any band hash are candidates.
  for band in 0..<bands:
    var buckets: Table[uint32, seq[int64]]
    for id, sig in pairs(sigs):
      let off = band * rows
      var bh: uint32 = 2166136261'u32                  # FNV-1a-ish fold
      for j in 0..<rows: bh = (bh xor sig[off + j]) * 16777619'u32
      buckets.mgetOrPut(bh, @[]).add(id)
    for ids in buckets.values:
      if ids.len > 1:
        for a in 0..<ids.len:
          for b in (a+1)..<ids.len:
            result.add((ids[a], ids[b]))

# ---------------------------------------------------------------- cluster assembly

proc clusterItems*(items: seq[ClusteringItem], threshold = 0.35,
                   bands = 20, rows = 6): ClusterResult =
  ## Full pipeline: signatures -> LSH candidates -> verify -> Union-Find.
  if items.len == 0: return result
  let numHashes = bands * rows
  var sigs: Table[int64, seq[uint32]]
  var itemById: Table[int64, ClusteringItem]
  var wordSets: Table[int64, HashSet[string]]
  for it in items:
    if not canCluster(it.title): continue
    sigs[it.id] = minhashSignature(it.title, numHashes)
    itemById[it.id] = it
    wordSets[it.id] = wordSet(it.title)

  var uf = initUnionFind()
  for (a, b) in lshCandidates(sigs, bands, rows):
    if a notin itemById or b notin itemById: continue
    let ia = itemById[a]; let ib = itemById[b]
    if ia.feedId == ib.feedId: continue                  # same-feed dedup
    if sameBaseDomain(ia.feedUrl, ib.feedUrl): continue  # same-domain dedup
    if overlapCoefficient(wordSets[a], wordSets[b]) >= threshold:
      uf.union(a, b)

  # group by root, representative = min member id
  var groups: Table[int64, seq[int64]]
  for id in itemById.keys:
    let root = uf.find(id)
    groups.mgetOrPut(root, @[]).add(id)
  for members in groups.values:
    let rep = min(members)
    result[rep] = members.sorted()
  return result

type NimClusterer* = ref object
proc cluster*(c: NimClusterer, items: seq[ClusteringItem]): ClusterResult =
  discard c
  clusterItems(items)

# ---------------------------------------------------------------- main

proc main() =
  let items = @[
    ClusteringItem(id: 1, title: "Apple announces new M4 chip for MacBooks", feedId: 1, feedUrl: "https://arstechnica.com"),
    ClusteringItem(id: 2, title: "Apple unveils M4 chip powering new MacBooks", feedId: 2, feedUrl: "https://theverge.com"),
    ClusteringItem(id: 3, title: "New MacBook Pro gets the M4 processor upgrade", feedId: 3, feedUrl: "https://techcrunch.com"),
    ClusteringItem(id: 4, title: "Severe flooding across southern Spain after days of heavy rain", feedId: 4, feedUrl: "https://bbc.com"),
    ClusteringItem(id: 5, title: "Days of heavy rain cause severe flooding across southern Spain", feedId: 5, feedUrl: "https://reuters.com"),
    ClusteringItem(id: 6, title: "NASA confirms date for next Artemis moon launch", feedId: 6, feedUrl: "https://nasa.gov"),
  ]
  let c = NimClusterer()
  let clusters = c.cluster(items)
  echo "=== clustering spike (", items.len, " items) ==="
  var clustered = 0
  for rep, members in pairs(clusters):
    if members.len > 1:
      echo "  cluster rep=", rep, " (", members.len, "): ", members
      clustered += members.len
  echo "Items in multi-member clusters: ", clustered
  doAssert 1 in clusters and 2 in clusters[1], "Apple headlines should cluster"
  doAssert 4 in clusters and 5 in clusters[4], "Spain flood headlines should cluster"
  doAssert 6 notin clusters or clusters[6].len == 1, "Artemis should NOT cluster"
  echo "Functional assertions PASSED"

when isMainModule: main()
