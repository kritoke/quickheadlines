## Sequential fetch pipeline.
##
## DESIGN CHANGE (was: N-thread worker pool sharing channels + refs). The
## thread-pool design fought Nim's ORC GC at every shared-deref: channels move
## heap-allocated FetchResults (containing seq[Item] with heap strings) across
## threads, the PipelineChannels ref is dereffed by every worker, and ORC's
## refcount operations are not atomic across threads. Result: intermittent
## "SIGSEGV: Illegal storage access" under load, reproducible only in production
## (FreeBSD), never on the dev box.
##
## Crystal achieved fetch parallelism with fibers on a single-thread event loop
## — no GC-across-threads problem. The safe Nim equivalent is to run fetches
## SEQUENTIALLY on the supervisor's own thread. Each fetch is a curl subprocess
## with a hard deadline, so no single feed can stall the loop. We lose raw
## parallelism (N feeds no longer fetch simultaneously), but the per-feed curl
## spawn is I/O-bound wall-clock, and 226 feeds × ~0.5s = ~2 min — acceptable
## for a 30-min refresh interval, and correctness beats crashing.
##
## Bounded parallelism can return later via async on a private event loop
## (cooperative, single-thread, no ORC-across-threads). This module is the
## safe baseline.

import std/[tables, sugar, monotimes, sets, atomics, times]
import ../types
import ../storage/[feed_store, content_store as cstore]
import ./http_fetcher

type
  FeedConfig* = object     ## a feed to fetch
    url*: string
    title*: string
  RefreshSummary* = object
    fetched*: int
    failed*: int
    items*: int
    failedUrls*: seq[string]   ## URLs that failed (for watchdog tracking)

proc refreshAll*(f: HttpFetcher; feeds: seq[FeedConfig];
                 store: SqliteFeedStore;
                 contentStore: SqliteContentStore = nil;
                 dirty: ref Atomic[bool] = nil;
                 maxConcurrency = 8;           ## ignored (kept for API compat)
                 batchDeadlineMs = 0): RefreshSummary =
  ## Fetch every feed sequentially and persist successes via the FeedStore.
  ## Persists INCREMENTALLY — each feed is written as its fetch completes, so
  ## readers see feeds progressively. `dirty` (if given) is set after EACH
  ## persist, so the WS watcher pushes feed_update as feeds land.
  ##
  ## `maxConcurrency` is accepted for call-site compatibility but intentionally
  ## ignored: the fetch loop is sequential (see module docstring for why).
  ## `batchDeadlineMs` (0 = no cap) sets a hard wall-clock budget for the whole
  ## batch; when exceeded, remaining feeds are counted as failed and skipped.
  if feeds.len == 0: return
  let byUrl = collect(initTable):
    for fc in feeds: {fc.url: fc.title}
  let start = getMonoTime()
  var done = initHashSet[string]()
  for fc in feeds:
    # Batch deadline check (wall-clock from start).
    if batchDeadlineMs > 0:
      let elapsed = (getMonoTime() - start).inMilliseconds.int
      if elapsed >= batchDeadlineMs:
        let abandoned = feeds.len - done.len
        if abandoned > 0:
          echo "[refresh] batch deadline hit, ", abandoned, " feeds abandoned"
          for f2 in feeds:
            if f2.url notin done:
              result.failedUrls.add(f2.url)
              inc result.failed
        break
    let r = fetchWithDeadline(f.userAgent, f.curlPath, fc.url)
    done.incl(fc.url)
    if r.isOk:
      inc result.fetched
      result.items += r.data.items.len
      var fd = r.data
      # Always use the configured title from feeds.yml (the user configures
      # display names there; RSS titles may differ or be generic).
      fd.title = byUrl.getOrDefault(fc.url, fd.title)
      # Persist article content to the content store before stripping.
      if not contentStore.isNil:
        for it in fd.items:
          if it.content.len > 0 and not cstore.isSummaryOnly(it.content):
            discard contentStore.storeContent(it.link, fc.url, it.title, it.content)
      # Strip content from in-memory items (saves memory; content is in the DB).
      for i in 0 ..< fd.items.len:
        fd.items[i].content = ""
      discard store.upsertWithItems(fd)            # favicon (if fetched) persisted with the feed
      if not dirty.isNil: dirty[].store(true)      # notify WS watcher per feed
    else:
      inc result.failed
      result.failedUrls.add(fc.url)
