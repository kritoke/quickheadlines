## Production HttpFetcher - satisfies the Fetcher concept (design D4).
## Promotes the spike's sync httpclient path + adds retry/backoff for
## transient network errors. The boundary returns the concrete FetchResult.

import std/[httpclient, os, strutils, osproc, uri]
import ../types
import ./rss

type
  HttpFetcher* = ref object
    timeoutMs*: int
    maxRetries*: int
    userAgent*: string
    curlPath*: string          # absolute curl path resolved at startup (avoids PATH dependency at runtime)
    useCurl: bool  # true if OpenSSL is broken (FreeBSD workaround)

const DefaultUserAgent* = "Mozilla/5.0 (compatible; QuickHeadlines/0.1; +https://github.com/kritoke/quickheadlines)"

proc findCurlPath(): string =
  ## Locate curl at startup, checking known absolute locations before PATH.
  ## On FreeBSD curl lives at /usr/local/bin/curl, which is often NOT on PATH
  ## for a daemon/service process (the runtime only sets LD_LIBRARY_PATH).
  ## Returning "" means curl is unavailable — callers must degrade gracefully.
  for candidate in ["/usr/local/bin/curl", "/usr/bin/curl", "/bin/curl",
                    "/usr/pkg/bin/curl", "/opt/local/bin/curl"]:
    if fileExists(candidate): return candidate
  # Fall back to PATH lookup.
  let (outp, code) = execCmdEx("command -v curl 2>/dev/null")
  if code == 0: result = outp.strip() else: result = ""

let CurlPath* = findCurlPath()   # resolved once at startup
let CurlAvailable* = CurlPath.len > 0

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
  if not CurlAvailable:
    # fetchWithDeadline requires curl; if it's missing, every feed fetch will
    # fail. Surface this loudly at startup so it's not a silent mystery.
    echo "[fetch] WARNING: curl not found on PATH or known locations — ",
         "feed fetching via fetchWithDeadline will fail. ",
         "Install curl or add its directory to PATH."
  else:
    echo "[fetch] curl found at: ", CurlPath
  HttpFetcher(timeoutMs: timeoutMs, maxRetries: maxRetries, userAgent: userAgent,
              curlPath: CurlPath, useCurl: useCurl)

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
  ## Transform feed URLs for compatibility.  Reddit subreddit URLs need the
  ## '.rss' suffix — the plain URL returns an HTML page, not an RSS feed.
  ## Uses URI parsing so only genuine reddit.com hosts are rewritten (a plain
  ## substring match would also hit e.g. 'notreddit.com'), and so a query
  ## string (e.g. '?sort=new') is preserved rather than corrupted.
  try:
    let p = parseUri(url)
    # Only rewrite genuine reddit.com subdomains (www., old., bare).
    if p.hostname.endsWith("reddit.com") and p.path.startsWith("/r/") and
       not p.path.endsWith(".rss"):
      var q = p
      q.path = p.path.strip(leading = false, trailing = true, chars = {'/'}) & "/.rss"
      result = $q
    else:
      result = url
  except CatchableError:
    result = url   # leave malformed URLs untouched; the fetcher will report the error

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

proc fetchWithDeadline*(userAgent, curlPath, url: string; deadlineMs = 20000): FetchResult =
  ## Fetch a single feed with a HARD wall-clock deadline.  Nim stdlib
  ## httpclient timeout does not reliably fire on slow-dribble/hung feeds
  ## (e.g. freshports.org accepts the TCP connection then never completes).
  ## We use system curl with --max-time which is a reliable process-level
  ## kill (sends SIGALRM), unlike socket timeouts that can be defeated by
  ## a server that trickles bytes or holds the connection open.
  ## The FeedData.url is ALWAYS the original config URL.
  ##
  ## Takes only value parameters (no ref objects) so it is safe to call from
  ## concurrent worker threads under ORC — sharing a ref object across threads
  ## and concurrently reading its string fields races on ORC refcount operations
  ## and intermittently SIGSEGVs (the 'Illegal storage access' crashes).
  if curlPath.len == 0 or not fileExists(curlPath):
    return errFetch(feNetwork)
  let actualUrl = transformFeedUrl(url)
  let timeoutSec = max(deadlineMs div 1000, 5)
  # --fail: exit non-zero on HTTP 4xx/5xx (restores status-code check lost when
  #   moving off httpclient; otherwise error-page HTML would reach parseRss).
  # Every interpolated value is quoteShell-escaped to prevent shell injection;
  # the User-Agent is a constant today, but we escape it defensively so a future
  # change to the UA string can never become an injection vector.
  # curlPath is an absolute path resolved at startup, so we don't depend on
  # PATH at runtime (FreeBSD daemons often lack /usr/local/bin on PATH).
  let cmd = quoteShell(curlPath) &
            " -sL --fail --max-time " & $timeoutSec &
            " -H " & quoteShell("Accept-Encoding: identity") &
            " -H " & quoteShell("Accept: application/rss+xml, application/atom+xml, application/xml, text/xml") &
            " -H " & quoteShell("User-Agent: " & userAgent) &
            " " & quoteShell(actualUrl)
  let (body, exitCode) = execCmdEx(cmd)
  if exitCode != 0:
    return errFetch(feNetwork)
  if body.len == 0:
    return errFetch(feNetwork)
  result = parseRss(url, body)
  if result.isOk:
    result.data.url = url
