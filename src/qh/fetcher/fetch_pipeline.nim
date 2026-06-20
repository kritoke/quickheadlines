## Concurrent fetch pipeline - promotes the Phase-1 spike's bounded-pool model
## into production. N worker threads fetch via the (retrying) HttpFetcher; the
## bounded work channel applies backpressure (design D5). Persistence is done
## by the caller on its own DbConn (SQLite connections are not thread-safe, so
## fetch is parallel and persist is serial - DB writes are the cheap part).

import std/[tables, sugar, sequtils]
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
                 maxConcurrency = 8): RefreshSummary =
  ## Fetch every feed concurrently and persist successes via the FeedStore.
  ## Returns a summary (fetched / failed / total items).
  let urls = feeds.mapIt(it.url)
  let outcomes = f.fetchAllConcurrent(urls, maxConcurrency)
  let byUrl = collect(initTable):
    for o in outcomes: {o.url: o.res}
  for fc in feeds:
    let r = byUrl.getOrDefault(fc.url)
    if r.isOk:
      inc result.fetched
      result.items += r.data.items.len
      var fd = r.data
      if fd.title.len == 0: fd.title = fc.title   # fall back to configured title
      discard store.upsertWithItems(fd)
    else:
      inc result.failed
