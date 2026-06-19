## Phase-1 fetch vertical spike (tasks 1.1).
##
## Concurrency model chosen: threads + bounded `Channel` + sync httpclient
## (design D5). This is the backpressure/ownership model the port exists to
## validate (the quickhea-alz memory-growth class of bug), and it sidesteps a
## Nim 2.2.4 limitation: generic `Result[T,E]` cannot be used with the
## `{.async.}` macro or with `concept`s (Future/concept instantiation fails
## on the generic error field). See findings in design.md.
##
## Validates:
##   * bounded `Channel[string]` work queue with backpressure (producer blocks)
##   * a worker-thread pool doing concurrent sync RSS fetch
##   * std/xmltree + std/xmlparser parsing (no libxml2 dep)
##   * generic `Result[T,E]` in sync code (errors as values, design D6)
## Measures: concurrent wall time, items parsed, per-feed status.
##
## Run: nim c --threads:on -d:ssl -r src/qh/spike/fetch_vertical.nim

import std/[httpclient, streams, strutils, times, xmltree, xmlparser]
import ../results
# Channel[T] (bounded) is a `system` builtin available with --threads:on.

# ---------------------------------------------------------------- domain

type
  FetchError* = enum
    feHttp      ## non-2xx / bad status
    feParse     ## malformed feed XML
    feNetwork   ## connection / DNS / timeout

  Item* = object
    title*: string
    link*: string
    pubDate*: string

  FeedData* = object
    title*: string
    url*: string
    items*: seq[Item]

  ## Documented Fetcher boundary (design D4). The intended interface is
  ## `fetch(url): Result[FeedData, FetchError]`. A Nim `concept` cannot
  ## enforce this on 2.2.4 (generic Result instantiation fails in concepts);
  ## Phase 2 will use concrete per-boundary result types or proc-set docs.
  ## HttpFetcher below implements the boundary.

# ---------------------------------------------------------------- RSS parse

# Boundary-local constructors: bind BOTH Result type params so `E` is never
# left unresolved (which would force a generic default and fail under
# --threads:on + ORC). Phase 2 will make these concrete per-boundary types.
template fetchOk*(fd: FeedData): Result[FeedData, FetchError] = ok[FeedData, FetchError](fd)
template fetchErr*(e: FetchError): Result[FeedData, FetchError] = err[FeedData, FetchError](e)

proc childText(n: XmlNode, tag: string): string =
  let c = n.child(tag)
  if c == nil: "" else: c.innerText.strip()

proc parseRss(url, body: string): Result[FeedData, FetchError] =
  try:
    let tree = parseXml(newStringStream(body))
    var fd = FeedData(url: url)
    let channel =
      if tree.tag == "channel": tree
      else: tree.child("channel")
    if channel != nil:
      fd.title = childText(channel, "title")
      for it in channel.findAll("item"):
        fd.items.add Item(
          title:  childText(it, "title"),
          link:   childText(it, "link"),
          pubDate: childText(it, "pubDate")
        )
    fetchOk(fd)
  except CatchableError:
    fetchErr(feParse)

# ---------------------------------------------------------------- sync fetch

proc fetchOneSync(url: string): Result[FeedData, FetchError] =
  let client = newHttpClient(timeout = 15000)
  try:
    let resp = client.request(url, HttpGet)
    let code = resp.code.int
    if code != 200 and code != 301 and code != 302 and code != 304:
      return fetchErr(feHttp)
    parseRss(url, resp.body)
  except CatchableError:
    fetchErr(feNetwork)
  finally:
    client.close()

type HttpFetcher* = ref object

proc fetch*(f: HttpFetcher, url: string): Result[FeedData, FetchError] =
  ## Documented Fetcher boundary impl.
  discard f
  fetchOneSync(url)

# ---------------------------------------------------------------- bounded pool

const NumWorkers = 4

type WorkerArgs = object
  jobs: ptr Channel[string]                         # bounded -> backpressure
  ress: ptr Channel[Result[FeedData, FetchError]]

proc worker(a: WorkerArgs) {.thread.} =
  while true:
    let url = a.jobs[].recv()                       # blocks until work available
    if url == "": break                             # sentinel -> stop
    a.ress[].send(fetchOneSync(url))

proc fetchAllBounded*(urls: seq[string]): seq[Result[FeedData, FetchError]] =
  var jobs: Channel[string]
  var ress: Channel[Result[FeedData, FetchError]]
  jobs.open(NumWorkers)                             # bounded: producer blocks when full
  ress.open(max(urls.len, 1))
  defer:
    jobs.close()
    ress.close()
  let a = WorkerArgs(jobs: addr(jobs), ress: addr(ress))
  var ths: array[NumWorkers, Thread[WorkerArgs]]
  for i in 0..<NumWorkers: ths[i].createThread(worker, a)
  for u in urls: jobs.send(u)                       # backpressure here
  for _ in 0..<NumWorkers: jobs.send("")            # one sentinel per worker
  result = @[]
  for _ in 0..<urls.len: result.add ress.recv()
  for i in 0..<NumWorkers: ths[i].joinThread()

# ---------------------------------------------------------------- main

proc truncate(s: string, n: int): string =
  if s.len <= n: s else: s[0..<n] & "..."

proc main() =
  let urls = @[
    "https://news.ycombinator.com/rss",
    "https://feeds.arstechnica.com/arstechnica/index",
    "https://www.techradar.com/feeds.xml",
    "https://hackaday.com/blog/feed/",
  ]
  let f = HttpFetcher()
  # sanity: boundary impl works on one feed
  let one = f.fetch(urls[0])
  doAssert one.isOk, "single fetch should succeed"

  echo "=== bounded-pool concurrent fetch (", NumWorkers, " workers) ==="
  let t0 = epochTime()
  let res = fetchAllBounded(urls)
  let wall = epochTime() - t0
  var total = 0
  for i, r in res:
    if r.isOk:
      echo "  ", urls[i], "\n     -> '", r.val.title.truncate(50), "' (",
        r.val.items.len, " items)"
      total += r.val.items.len
    else:
      echo "  ", urls[i], "\n     -> ERR ", r.err
  echo "Total items parsed: ", total
  echo "Concurrent wall time: ", wall.formatFloat(ffDecimal, 4), "s for ", urls.len, " feeds"

when isMainModule: main()
