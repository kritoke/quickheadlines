## Concurrent fetch pipeline - promotes the Phase-1 spike's bounded-pool model
## into production. N worker threads fetch via the (retrying) HttpFetcher; the
## bounded work channel applies backpressure (design D5). Persistence is done
## by the caller on its own DbConn (SQLite connections are not thread-safe, so
## fetch is parallel and persist is serial - DB writes are the cheap part).

import std/[tables, sugar, sequtils, atomics]
import ../types
import ../storage/feed_store
import ./http_fetcher

type
  FeedConfig* = object     ## a feed to fetch
    url*: string
    title*: string
  FetchOutcome* = object   ## url + the fetch result
    url*: string
    res*: FetchResult
  RefreshSummary* = object
    fetched*: int
    failed*: int
    items*: int

type WorkerArgs = object
  fetcher: HttpFetcher
  jobs: ptr Channel[string]
  ress: ptr Channel[FetchOutcome]

proc worker(a: WorkerArgs) {.thread.} =
  while true:
    let url = a.jobs[].recv()
    if url == "": break                          # sentinel -> stop
    a.ress[].send(FetchOutcome(url: url, res: a.fetcher.fetch(url)))

proc fetchAllConcurrent*(f: HttpFetcher; urls: seq[string];
                         maxConcurrency = 8): seq[FetchOutcome] =
  ## Fetch `urls` concurrently with a bounded work pool. Producer blocks when
  ## the work channel is full (backpressure).
  let n = maxConcurrency.clamp(1, 32)
  var jobs: Channel[string]
  var ress: Channel[FetchOutcome]
  jobs.open(n)                                   # bounded -> backpressure
  ress.open(max(urls.len, 1))
  defer:
    jobs.close()
    ress.close()
  let a = WorkerArgs(fetcher: f, jobs: addr(jobs), ress: addr(ress))
  var ths: seq[Thread[WorkerArgs]]
  newSeq(ths, n)
  for i in 0..<n: ths[i].createThread(worker, a)
  for u in urls: jobs.send(u)                    # backpressure point
  for _ in 0..<n: jobs.send("")                  # one sentinel per worker
  for _ in 0..<urls.len: result.add ress.recv()
  for i in 0..<n: ths[i].joinThread()

proc refreshAll*(f: HttpFetcher; feeds: seq[FeedConfig];
                 store: SqliteFeedStore;
                 dirty: ref Atomic[bool] = nil;
                 maxConcurrency = 8): RefreshSummary =
  ## Fetch every feed concurrently and persist successes via the FeedStore.
  ## Persists INCREMENTALLY - each feed is written as its fetch completes, so
  ## readers (and the /api/feeds long-poll) see feeds progressively. `dirty`
  ## (if given) is set after EACH persist, so the WS watcher pushes feed_update
  ## as feeds land - not delayed by the slowest/hanging feed.
  let urls = feeds.mapIt(it.url)
  let n = maxConcurrency.clamp(1, 32)
  var jobs: Channel[string]
  var ress: Channel[FetchOutcome]
  jobs.open(n)                                   # bounded -> backpressure
  ress.open(max(urls.len, 1))
  let byUrl = collect(initTable):
    for fc in feeds: {fc.url: fc.title}
  let a = WorkerArgs(fetcher: f, jobs: addr(jobs), ress: addr(ress))
  var ths: seq[Thread[WorkerArgs]]
  newSeq(ths, n)
  for i in 0..<n: ths[i].createThread(worker, a)
  for u in urls: jobs.send(u)                    # backpressure point
  for _ in 0..<n: jobs.send("")                  # one sentinel per worker
  # Consume + persist each outcome as it arrives (progressive hydration).
  for _ in 0..<urls.len:
    let o = ress.recv()
    if o.res.isOk:
      inc result.fetched
      result.items += o.res.data.items.len
      var fd = o.res.data
      if fd.title.len == 0: fd.title = byUrl.getOrDefault(o.url)
      discard store.upsertWithItems(fd)            # favicon (if fetched) persisted with the feed
      if not dirty.isNil: dirty[].store(true)      # notify WS watcher per feed
    else:
      inc result.failed
  for i in 0..<n: ths[i].joinThread()
  jobs.close()
  ress.close()
