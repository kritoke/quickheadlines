## Favicon fetcher - port of key vug.cr features into Nim.
## Tries multiple sources in order, validates downloaded content is a real image,
## and falls back to Google/DuckDuckGo favicon services for broad coverage.
##
## Sources (in order):
##   1. Multiple paths at the site origin (/favicon.ico, /favicon.png, etc.)
##   2. HTML <link rel="icon"> parse (plain string, async-safe)
##   3. Google favicon service (https://www.google.com/s2/favicons)
##   4. DuckDuckGo favicon service (https://icons.duckduckgo.com)
##
## Each download is validated against known image magic bytes before saving
## (prevents saving HTML error pages as favicons - a real failure mode).

import std/[httpclient, asyncdispatch, uri, strutils, os, options, algorithm]


const
  FavUserAgent = "Mozilla/5.0 (compatible; QuickHeadlines/0.1; +https://github.com/kritoke/quickheadlines)"
  GoogleFaviconSize = 256

type FavBytes* = object
  bytes*: string
  ext*: string

# ---- URL helpers ----

proc originOf(u: string): string =
  try:
    let p = parseUri(u)
    if p.hostname.len == 0: return ""
    let auth = if p.port.len > 0: p.hostname & ":" & p.port else: p.hostname
    let scheme = if p.scheme.len > 0: p.scheme else: "https"
    scheme & "://" & auth
  except CatchableError: ""

proc extractHost*(u: string): string =
  try: parseUri(u).hostname
  except CatchableError: ""

proc resolveHref(origin, href: string): string =
  let h = href.strip()
  if h.startsWith("http://") or h.startsWith("https://"): return h
  if h.startsWith("//"): return "https:" & h
  if h.startsWith("/"): return origin & h
  origin & "/" & h

# ---- image validation (port of vug.cr ImageValidator) ----

proc isPng(data: string): bool =
  data.len >= 8 and data[0] == '\x89' and data[1] == 'P' and data[2] == 'N' and data[3] == 'G'

proc isJpeg(data: string): bool =
  data.len >= 3 and data[0] == '\xFF' and data[1] == '\xD8' and data[2] == '\xFF'

proc isIco(data: string): bool =
  data.len >= 4 and data[0] == '\x00' and data[1] == '\x00' and data[2] == '\x01' and data[3] == '\x00'

proc isSvg(data: string): bool =
  let s = data.strip()
  s.len >= 4 and (s.startsWith("<svg") or s.startsWith("<?xml"))

proc isWebp(data: string): bool =
  data.len >= 12 and data[0] == 'R' and data[1] == 'I' and data[2] == 'F' and data[3] == 'F' and
    data[8] == 'W' and data[9] == 'E' and data[10] == 'B' and data[11] == 'P'

proc isGif(data: string): bool =
  data.len >= 6 and data[0] == 'G' and data[1] == 'I' and data[2] == 'F'

proc validImage*(data: string): bool =
  data.len >= 4 and (isPng(data) or isJpeg(data) or isIco(data) or
    isSvg(data) or isWebp(data) or isGif(data))

proc detectExt*(data: string): string =
  if isSvg(data): "svg"
  elif isPng(data): "png"
  elif isJpeg(data): "jpg"
  elif isWebp(data): "webp"
  elif isGif(data): "gif"
  else: "ico"

# ---- async HTTP fetch helpers ----

proc followFetch(client: AsyncHttpClient; url: string;
                 maxHops = 3): Future[Option[string]] {.async.} =
  var currentUrl = url
  for _ in 0..maxHops:
    let resp = await client.request(currentUrl, HttpGet)
    let code = resp.code.int
    if code == 301 or code == 302 or code == 303 or code == 307 or code == 308:
      let locSeq = seq[string](resp.headers.getOrDefault("Location"))
      if locSeq.len == 0: return none(string)
      let loc = locSeq[0]
      if loc.len == 0: return none(string)
      currentUrl = (if loc.startsWith("http"): loc else: currentUrl.rsplit("/",1)[0] & "/" & loc)
      continue
    if code == 200:
      return some(await resp.body)
    return none(string)
  none(string)

proc tryFetchValidImage(client: AsyncHttpClient; url: string): Future[Option[FavBytes]] {.async.} =
  let body = await client.followFetch(url)
  if body.isSome and validImage(body.get) and body.get.len >= 50:
    return some(FavBytes(bytes: body.get, ext: detectExt(body.get)))
  none(FavBytes)

# ---- HTML <link rel="icon"> parse (plain string, no regex) ----

proc findIconHrefs(html, origin: string): seq[string] =
  ## Extract favicon URLs from HTML <link> tags. Prefers .png/.svg over .ico.
  var pos = 0
  while pos < html.len:
    let linkStart = html.find("<link", pos)
    if linkStart < 0: break
    let linkEnd = html.find(">", linkStart)
    if linkEnd < 0: break
    let tag = html[linkStart ..< linkEnd]
    pos = linkEnd + 1
    let tagLower = tag.toLowerAscii()
    if "icon" notin tagLower: continue
    # Extract href="..." or href='...'
    let hrefPos = tagLower.find("href=")
    if hrefPos < 0: continue
    let afterEq = tag[hrefPos + 5 .. ^1].strip()
    if afterEq.len < 2: continue
    let q = afterEq[0]
    if q != '"' and q != '\'': continue
    let eq = afterEq.find(q, 1)
    if eq < 1: continue
    let href = afterEq[1 ..< eq]
    if href.len > 0:
      let resolved = resolveHref(origin, href)
      if resolved notin result: result.add(resolved)
  # Prefer .png/.svg over .ico (better quality, port of vug.cr sort)
  result.sort do (a, b: string) -> int:
    let sa = (if a.endsWith(".png") or a.endsWith(".svg"): 0 elif a.endsWith(".ico"): 2 else: 1)
    let sb = (if b.endsWith(".png") or b.endsWith(".svg"): 0 elif b.endsWith(".ico"): 2 else: 1)
    cmp(sa, sb)

# ---- fallback URL builders (port of vug.cr FallbackUrls) ----

proc googleFaviconUrl*(domain: string): string =
  "https://www.google.com/s2/favicons?domain=" & encodeUrl(domain) & "&sz=" & $GoogleFaviconSize

proc duckduckgoFaviconUrl*(domain: string): string =
  "https://icons.duckduckgo.com/ip3/" & encodeUrl(domain) & ".ico"

# ---- main entry point ----

proc fetchFaviconAsync*(siteLink, feedUrl: string): Future[Option[FavBytes]] {.async.} =
  ## Async favicon fetch (runs in server event loop, proper timeout).
  ## Tries: multiple paths -> HTML parse -> Google fallback -> DuckDuckGo fallback.
  let origin = if siteLink.len > 0: originOf(siteLink) else: originOf(feedUrl)
  if origin.len == 0: return none(FavBytes)
  let host = extractHost(if siteLink.len > 0: siteLink else: feedUrl)
  let client = newAsyncHttpClient()
  client.headers = newHttpHeaders({"User-Agent": FavUserAgent, "Accept-Encoding": "identity"})
  try:
    # 1. Parse homepage HTML for <link rel="icon"> first — usually has the
    #    largest/best-quality icon (SVG, large PNG, apple-touch-icon).
    #    vug.cr also prefers HTML <link> over direct paths for this reason.
    let htmlOpt = await client.followFetch(origin & "/")
    if htmlOpt.isSome:
      let raw = htmlOpt.get
      # If the response is gzip-compressed (0x1F 0x8B), we can't parse it
      # (std/zlib isn't available in this nix Nim build). Skip and fall through
      # to Google/DuckDuckGo which serve uncompressed.
      let isGzip = raw.len > 2 and raw[0] == '\x1F' and raw[1] == '\x8B'
      if not isGzip:
        let hrefs = findIconHrefs(raw, origin)
        for href in hrefs:
          let r = await client.tryFetchValidImage(href)
          if r.isSome: return r

    # 2. Try common favicon paths at the site origin.
    for path in ["/favicon.png", "/apple-touch-icon.png",
                 "/apple-touch-icon-180x180.png", "/favicon.ico"]:
      let r = await client.tryFetchValidImage(origin & path)
      if r.isSome: return r

    # 3. Google favicon service fallback (broad coverage)
    if host.len > 0:
      let r = await client.tryFetchValidImage(googleFaviconUrl(host))
      if r.isSome: return r

    # 4. DuckDuckGo favicon service fallback
    if host.len > 0:
      let r = await client.tryFetchValidImage(duckduckgoFaviconUrl(host))
      if r.isSome: return r

  except CatchableError:
    discard
  finally:
    client.close()
  none(FavBytes)

proc faviconHash*(origin: string): string =
  var h: uint64 = 14695981039346656037'u64
  for c in origin: h = h xor uint64(c); h = h * 1099511628211'u64
  result = h.toHex().toLowerAscii()

proc saveFavicon*(fav: FavBytes; origin: string; dir = "favicons"): string =
  createDir(dir)
  let stem = faviconHash(origin)
  let path = dir & "/" & stem & "." & fav.ext
  writeFile(path, fav.bytes)
  "/favicons/" & stem & "." & fav.ext
