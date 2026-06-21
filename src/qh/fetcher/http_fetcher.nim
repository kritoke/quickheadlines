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

proc transformFeedUrl*(url: string): string =
  ## Reddit subreddit URLs need .rss suffix to get RSS feeds.
  ## www.reddit.com/r/technology -> www.reddit.com/r/technology/.rss
  if url.contains("reddit.com/r/") and not url.endsWith(".rss"):
    let base = url.strip(chars={'/'})
    return base & "/.rss"
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
