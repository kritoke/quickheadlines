## Concurrent fetch pipeline - promotes the Phase-1 spike's bounded-pool model
## into production. N worker threads fetch via the (retrying) HttpFetcher with a
## HARD per-feed deadline (fetchWithDeadline); the bounded work channel applies
## backpressure (design D5). Persistence is done by the caller on its own DbConn
## (SQLite connections are not thread-safe, so fetch is parallel and persist is
## serial - DB writes are the cheap part).

import std/[tables, sugar, sequtils, atomics, monotimes, sets, os, times]
import ../types
import ../storage/[feed_store, content_store as cstore]
import ./http_fetcher

type
  FeedConfig* = object     ## a feed to fetch
    url*: string
    title*: string
  FetchOutcome* = object   ## url + the fetch result
    url: string
    res: FetchResult
  RefreshSummary* = object
    fetched*: int
    failed*: int
    items*: int
    failedUrls*: seq[string]   ## URLs that failed (for watchdog tracking)

  PipelineChannels = ref object
    ## Heap-allocated channels so they survive worker detachment when a
    ## batch deadline causes early return.
    jobs: Channel[string]
    ress: Channel[FetchOutcome]

  WorkerArgs = object
    fetcher: HttpFetcher
    chans: PipelineChannels

proc worker(a: WorkerArgs) {.thread.} =
  while true:
    let url = a.chans.jobs.recv()
    if url == "": break                          # sentinel -> stop
    a.chans.ress.send(FetchOutcome(url: url, res: a.fetcher.fetchWithDeadline(url)))

proc fetchAllConcurrent*(f: HttpFetcher; urls: seq[string];
                         maxConcurrency = 8): seq[FetchOutcome] =
  ## Fetch `urls` concurrently with a bounded work pool. Producer blocks when
  ## the work channel is full (backpressure).
  let n = maxConcurrency.clamp(1, 32)
  let chans = PipelineChannels()
  chans.jobs.open(n)                             # bounded -> backpressure
  chans.ress.open(n)                             # bounded -> memory cap
  let a = WorkerArgs(fetcher: f, chans: chans)
  var ths: seq[Thread[WorkerArgs]]
  newSeq(ths, n)
  for i in 0..<n: ths[i].createThread(worker, a)
  for u in urls: chans.jobs.send(u)              # backpressure point
  for _ in 0..<n: chans.jobs.send("")            # one sentinel per worker
  for _ in 0..<urls.len: result.add chans.ress.recv()
  for i in 0..<n: ths[i].joinThread()
  chans.jobs.close()
  chans.ress.close()

proc refreshAll*(f: HttpFetcher; feeds: seq[FeedConfig];
                 store: SqliteFeedStore;
                 contentStore: SqliteContentStore = nil;
                 dirty: ref Atomic[bool] = nil;
                 maxConcurrency = 8;
                 batchDeadlineMs = 0): RefreshSummary =
  ## Fetch every feed concurrently and persist successes via the FeedStore.
  ## Persists INCREMENTALLY - each feed is written as its fetch completes, so
  ## readers (and the /api/feeds long-poll) see feeds progressively. `dirty`
  ## (if given) is set after EACH persist, so the WS watcher pushes feed_update
  ## as feeds land - not delayed by the slowest/hanging feed.
  ## If contentStore is provided, article content is persisted and stripped from
  ## in-memory items (port of Crystal persist_entry_content + strip_content).
  ## `batchDeadlineMs` (0 = no cap) sets a hard wall-clock budget for the entire
  ## batch. When exceeded, remaining feeds are counted as failed and abandoned
  ## (their worker threads are detached).
  if feeds.len == 0: return
  let urls = feeds.mapIt(it.url)
  let n = maxConcurrency.clamp(1, 32)
  let chans = PipelineChannels()
  chans.jobs.open(max(urls.len, n))           # large enough that producer never blocks
  chans.ress.open(max(urls.len, n))            # large enough that workers NEVER block on send (critical: if the batch deadline detaches the consumer, a full ress would deadlock workers on send and they'd never reach their sentinel -> thread leak)
  let byUrl = collect(initTable):
    for fc in feeds: {fc.url: fc.title}
  let a = WorkerArgs(fetcher: f, chans: chans)
  var ths: seq[Thread[WorkerArgs]]
  newSeq(ths, n)
  for i in 0..<n: ths[i].createThread(worker, a)
  for u in urls: chans.jobs.send(u)              # backpressure point
  for _ in 0..<n: chans.jobs.send("")            # one sentinel per worker

  # Consume + persist each outcome as it arrives (progressive hydration).
  # Uses a poll loop so a batch deadline can abandon stragglers.
  # NOTE: the loop-exit condition uses a COUNTER (received), not the
  # receivedSet's len, because duplicate feed URLs across tabs are legal —
  # a HashSet len would never reach urls.len and the loop would spin forever.
  var received = 0
  var receivedSet = initHashSet[string]()
  let start = getMonoTime()
  while received < urls.len:
    let r = chans.ress.tryRecv()
    if r.dataAvailable:
      let o = r.msg
      inc received
      receivedSet.incl(o.url)
      if o.res.isOk:
        inc result.fetched
        result.items += o.res.data.items.len
        var fd = o.res.data
        # Always use the configured title from feeds.yml (the user configures
        # display names there; RSS titles may differ or be generic).
        fd.title = byUrl.getOrDefault(o.url, fd.title)
        # Persist article content to the content store before stripping.
        if not contentStore.isNil:
          for it in fd.items:
            if it.content.len > 0 and not cstore.isSummaryOnly(it.content):
              discard contentStore.storeContent(it.link, o.url, it.title, it.content)
        # Strip content from in-memory items (saves memory; content is in the DB).
        for i in 0 ..< fd.items.len:
          fd.items[i].content = ""
        discard store.upsertWithItems(fd)          # favicon (if fetched) persisted with the feed
        if not dirty.isNil: dirty[].store(true)    # notify WS watcher per feed
      else:
        inc result.failed
        result.failedUrls.add(o.url)
    else:
      sleep(100)
    # Check batch deadline (wall-clock from start).
    if batchDeadlineMs > 0:
      let elapsed = (getMonoTime() - start).inMilliseconds.int
      if elapsed >= batchDeadlineMs:
        let abandoned = urls.len - received
        if abandoned > 0:
          echo "[refresh] batch deadline hit, ", abandoned, " feeds abandoned"
          for u in urls:
            if u notin receivedSet:
              result.failedUrls.add(u)
              inc result.failed
        break

  # Join workers when all results received (clean exit).  When the batch
  # deadline was hit, detach the still-running workers — they hold a ref to
  # the PipelineChannels so it stays alive until they terminate. Workers can
  # always drain ress (capacity >= urls.len) and reach their sentinel, so no
  # thread is stranded on a blocked send.
  if received == urls.len:
    for i in 0..<n: ths[i].joinThread()
    chans.jobs.close()
    chans.ress.close()
  else:
    echo "[refresh] detaching ", n, " worker threads (batch deadline exceeded)"
