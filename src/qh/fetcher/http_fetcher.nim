## Production HttpFetcher - satisfies the Fetcher concept (design D4).
## Promotes the spike's sync httpclient path + adds retry/backoff for
## transient network errors. The boundary returns the concrete FetchResult.

import std/[httpclient, os, strutils]
import ../types
import ./rss

type
  HttpFetcher* = ref object
    timeoutMs*: int
    maxRetries*: int
    userAgent*: string

const DefaultUserAgent* = "Mozilla/5.0 (compatible; QuickHeadlines/0.1; +https://github.com/kritoke/quickheadlines)"

proc newHttpFetcher*(timeoutMs = 15000, maxRetries = 2,
                     userAgent = DefaultUserAgent): HttpFetcher =
  HttpFetcher(timeoutMs: timeoutMs, maxRetries: maxRetries, userAgent: userAgent)

# Thread-local client: reused across fetch calls within the same worker thread.
# Avoids racing on getDefaultSSL() lazy init (OpenSSL isn't thread-safe).
var threadClient {.threadvar.}: HttpClient
var threadClientAgent {.threadvar.}: string

proc getThreadClient(f: HttpFetcher): HttpClient =
  if threadClient == nil or threadClientAgent != f.userAgent:
    if threadClient != nil:
      try: threadClient.close() except CatchableError: discard
    threadClient = newHttpClient(timeout = f.timeoutMs)
    threadClient.headers = newHttpHeaders({
      "User-Agent": f.userAgent,
      "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml",
      "Accept-Encoding": "identity"})
    threadClientAgent = f.userAgent
  threadClient

proc fetchOnce(f: HttpFetcher; url: string): FetchResult =
  let client = f.getThreadClient()
  try:
    let resp = client.request(url, HttpGet)
    let code = resp.code.int
    if code != 200 and code != 301 and code != 302 and code != 304:
      echo "[fetch] ", url[0..min(50,url.len-1)], " HTTP ", code
      return errFetch(feHttp)
    parseRss(url, resp.body)
  except CatchableError as e:
    echo "[fetch] ", url[0..min(50,url.len-1)], " ERROR: ", e.msg[0..min(80,e.msg.len-1)]
    errFetch(feNetwork)

proc backoffMs(attempt: int): int =
  ## Exponential backoff: 100ms, 200ms, 400ms... (capped at 2s).
  min(100 * (1 shl attempt), 2000)

proc transformFeedUrl*(url: string): string =
  ## No-op: the plain subreddit URL works (Reddit redirects with Accept headers).
  ## Appending .rss triggers aggressive rate-limiting (429).
  url

proc fetch*(f: HttpFetcher; url: string): FetchResult =
  ## Boundary proc. Retries on transient (network) errors up to maxRetries,
  ## with exponential backoff. HTTP-status and parse errors are not retried.
  ## The FeedData.url is ALWAYS the original config URL (not the transformed
  ## fetch URL), so the tab filter and favicon lookup work correctly.
  let actualUrl = transformFeedUrl(url)
  var last = errFetch(feNetwork)
  for attempt in 0..f.maxRetries:
    last = f.fetchOnce(actualUrl)
    if last.isOk:
      # Restore the original config URL as the feed's identity.
      last.data.url = url
      return last
    if last.err != feNetwork: return last
    if attempt < f.maxRetries:
      sleep(backoffMs(attempt))
  last
