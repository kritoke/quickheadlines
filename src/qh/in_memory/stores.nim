## In-memory test impls for the Store boundaries (design D4 / spec
## nim-black-box-boundaries: "Replaceability via in-memory test impls").
## These let unit tests run without SQLite. State is per-instance (ref object
## fields), never module-level. Production SQLite impls come in Phase 3.

import ../types
import std/tables

type
  InMemoryFeedStore* = ref object
    rows*: seq[FeedRow]

proc upsertFeed*(s: InMemoryFeedStore, f: FeedRow): StoreUnitResult =
  var found = false
  for i in 0..<s.rows.len:
    if s.rows[i].url == f.url:
      s.rows[i] = f
      found = true
      break
  if not found: s.rows.add(f)
  okStore()

proc listFeeds*(s: InMemoryFeedStore): FeedListResult =
  okFeeds(s.rows)

type
  InMemoryItemStore* = ref object
    entries*: seq[TimelineEntry]

proc findTimeline*(s: InMemoryItemStore; limit, offset: int;
                   daysBack: int): TimelineResult =
  ## Port-shaped signature of StoryRepository.find_timeline_items. The
  ## in-memory impl just slices; daysBack is honoured only if > 0 (skipped
  ## here since entries carry string dates - production parses them).
  let total = s.entries.len
  let hi = min(offset + limit, total)
  let lo = min(offset, total)
  okTimeline(s.entries[lo..<hi], total)

type
  InMemoryClusterStore* = ref object
    clusters*: Cluster

proc assignClusters*(s: InMemoryClusterStore, c: Cluster): StoreUnitResult =
  s.clusters = c
  okStore()

proc clearClusters*(s: InMemoryClusterStore): StoreUnitResult =
  s.clusters.clear()
  okStore()
