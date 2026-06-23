## Production HttpFetcher - satisfies the Fetcher concept (design D4).
## Promotes the spike's sync httpclient path + adds retry/backoff for
## transient network errors. The boundary returns the concrete FetchResult.

import std/[httpclient, os, strutils, osproc, streams]
import ../types
import ./rss

type
  HttpFetcher* = ref object
    timeoutMs*: int
    maxRetries*: int
    userAgent*: string
    useCurl: bool  # true if OpenSSL is broken (FreeBSD workaround)

const DefaultUserAgent* = "Mozilla/5.0 (compatible; QuickHeadlines/0.1; +https://github.com/kritoke/quickheadlines)"

proc fetchViaCurl(url: string; timeoutMs: int): (int, string) =
  ## Fallback: use system curl for HTTPS when Nim's OpenSSL is broken.
  let timeoutSec = max(timeoutMs div 1000, 5)
  let (output, exitCode) = execCmdEx(
    "curl -sL --max-time " & $timeoutSec & " -H 'Accept-Encoding: identity' " & quoteShell(url))
  (exitCode, output)

proc newHttpFetcher*(timeoutMs = 15000, maxRetries = 2,
                     userAgent = DefaultUserAgent): HttpFetcher =
  # On FreeBSD, OpenSSL context creation can SIGSEGV. Set
  # QUICKHEADLINES_USE_CURL=1 to use system curl as fallback.
  let useCurl = getEnv("QUICKHEADLINES_USE_CURL", "0") == "1"
  if useCurl:
    echo "[fetch] Using curl fallback for HTTP requests"
  HttpFetcher(timeoutMs: timeoutMs, maxRetries: maxRetries, userAgent: userAgent,
              useCurl: useCurl)

proc fetchOnce(f: HttpFetcher; url: string): FetchResult =
  # Use curl fallback if httpclient SSL is broken.
  if f.useCurl:
    let (code, body) = fetchViaCurl(url, f.timeoutMs)
    if code != 0:
      echo "[fetch] ", url[0..min(50,url.len-1)], " curl exit=", code
      return errFetch(feNetwork)
    if body.len == 0:
      echo "[fetch] ", url[0..min(50,url.len-1)], " curl empty response"
      return errFetch(feNetwork)
    return parseRss(url, body)

  let client = newHttpClient(timeout = f.timeoutMs)
  client.headers = newHttpHeaders({
    "User-Agent": f.userAgent,
    "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml",
    "Accept-Encoding": "identity"})
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
  finally:
    client.close()

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
