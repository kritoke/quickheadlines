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

const DefaultUserAgent* = "QuickHeadlines-Nim/0.1 (+https://github.com/kritoke/quickheadlines)"

proc newHttpFetcher*(timeoutMs = 15000, maxRetries = 2,
                     userAgent = DefaultUserAgent): HttpFetcher =
  HttpFetcher(timeoutMs: timeoutMs, maxRetries: maxRetries, userAgent: userAgent)

proc fetchOnce(f: HttpFetcher; url: string): FetchResult =
  let client = newHttpClient(timeout = f.timeoutMs)
  client.headers = newHttpHeaders({"User-Agent": f.userAgent})
  try:
    let resp = client.request(url, HttpGet)
    let code = resp.code.int
    if code != 200 and code != 301 and code != 302 and code != 304:
      return errFetch(feHttp)
    parseRss(url, resp.body)
  except CatchableError:
    errFetch(feNetwork)
  finally:
    client.close()

proc backoffMs(attempt: int): int =
  ## Exponential backoff: 100ms, 200ms, 400ms... (capped at 2s).
  min(100 * (1 shl attempt), 2000)

proc fetch*(f: HttpFetcher; url: string): FetchResult =
  ## Boundary proc. Retries on transient (network) errors up to maxRetries,
  ## with exponential backoff. HTTP-status and parse errors are not retried
  ## (they won't fix themselves in 200ms).
  var last = errFetch(feNetwork)
  for attempt in 0..f.maxRetries:
    last = f.fetchOnce(url)
    if last.isOk: return last
    if last.err != feNetwork: return last   # feHttp / feParse: don't retry
    if attempt < f.maxRetries:
      sleep(backoffMs(attempt))
  last
