## Clustering engine - port of src/services/clustering_engine.cr (which uses
## lexis-minhash + prismatiq in Crystal). Pure algorithms, no I/O: text
## normalisation, MinHash signatures, LSH banding, Union-Find, overlap-coeff
## verification, same-feed/same-domain dedup. Promoted from the Phase-1 spike.
##
## Exact byte-equality of cluster IDs with the Crystal backend requires
## matching lexis-minhash's hash functions on frozen fixtures (Phase-2 deferral
## Q3); this uses a standard salted MinHash. The algorithm ports; the hash
## identity is the only remaining gap.

import std/[hashes, sets, tables, strutils, sequtils, algorithm, uri]
import ../types

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
const MinWordsForClustering* = 4

proc normalizeHeadline*(text: string): string =
  if text.len == 0: return ""
  text.toLowerAscii().strip().splitWhitespace().filterIt(it notin StopWords).join(" ")

proc wordSet*(text: string): HashSet[string] =
  toHashSet(normalizeHeadline(text).splitWhitespace())

proc overlapCoefficient*(a, b: HashSet[string]): float =
  if a.card == 0 or b.card == 0: return 0.0
  let inter = a * b
  if inter.card == 0: return 0.0
  inter.card.float / min(a.card, b.card).float

proc canCluster*(title: string): bool =
  title.len > 0 and normalizeHeadline(title).splitWhitespace().len >= MinWordsForClustering

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

proc minhashSignature*(title: string, numHashes: int): seq[uint32] =
  ## Standard MinHash over salted word hashes. numHashes = bands * rows.
  result = newSeq[uint32](numHashes)
  for i in 0..<numHashes: result[i] = high(uint32)
  for w in normalizeHeadline(title).splitWhitespace():
    for i in 0..<numHashes:
      let h = uint32(hash(w & "#" & $i))
      if h < result[i]: result[i] = h

proc bandHashes*(sig: seq[uint32]; bands, rows: int): seq[(int, string)] =
  ## Fold each band's `rows` signature slots into a uint32 (FNV-1a) and return
  ## (bandIndex, hexHash) pairs. These are what ClusterStore stores/queries.
  for band in 0..<bands:
    var bh: uint32 = 2166136261'u32
    for j in 0..<rows:
      bh = (bh xor sig[band * rows + j]) * 16777619'u32
    result.add((band, ($bh).toLowerAscii()))

# ---------------------------------------------------------------- Union-Find

type UnionFind* = object
  parent: Table[int64, int64]

proc initUnionFind*(): UnionFind = UnionFind()

proc find*(uf: var UnionFind; x: int64): int64 =
  if x notin uf.parent: uf.parent[x] = x
  result = x
  while uf.parent[result] != result: result = uf.parent[result]
  var cur = x
  while uf.parent[cur] != result:                 # path compression
    let nxt = uf.parent[cur]
    uf.parent[cur] = result
    cur = nxt

proc union*(uf: var UnionFind; a, b: int64) =
  let (ra, rb) = (uf.find(a), uf.find(b))
  if ra == rb: return
  if ra < rb: uf.parent[rb] = ra else: uf.parent[ra] = rb   # smaller id wins

# ---------------------------------------------------------------- cluster assembly (pure)

proc buildClustersFromPairs*(pairs: seq[(int64, int64)]; itemIds: seq[int64]): Cluster =
  ## Union-Find the pairs, group by root, representative = min member id.
  var uf = initUnionFind()
  for (a, b) in pairs: uf.union(a, b)
  var groups: Table[int64, seq[int64]]
  for id in itemIds:
    groups.mgetOrPut(uf.find(id), @[]).add(id)
  for members in groups.values:
    if members.len > 1:
      result[min(members)] = members.sorted()
