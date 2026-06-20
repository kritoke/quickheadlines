## Simple favicon fetcher - the 80%-of-sites core (NOT a full vug.cr port).
## Just GET {origin}/favicon.ico. Deliberately avoids std/re (regex) because the
## re module is not safe inside the fetch worker threads (it hung the refresh).
## The HTML <link rel=icon> parse can be added later via a non-threaded path.

import std/[httpclient, asyncdispatch, uri, strutils, os, options]

const FavTimeoutMs = 4000
const FavUserAgent = "QuickHeadlines-Nim/0.1 (+https://github.com/kritoke/quickheadlines)"
type FavBytes* = object
  bytes*: string
  ext*: string     ## "ico" | "png" | "svg" | "jpg"

proc originOf(u: string): string =
  try:
    let p = parseUri(u)
    if p.hostname.len == 0: return ""
    let auth = if p.port.len > 0: p.hostname & ":" & p.port else: p.hostname
    let scheme = if p.scheme.len > 0: p.scheme else: "https"
    scheme & "://" & auth
  except CatchableError:
    ""

proc ctToExt(ct: string): string =
  let c = ct.toLowerAscii()
  if "svg" in c: "svg"
  elif "png" in c: "png"
  elif "jpeg" in c or "jpg" in c: "jpg"
  else: "ico"

proc fetchFavicon*(siteLink, feedUrl: string): Option[FavBytes] =
  ## Best-effort: GET {origin}/favicon.ico. none on any miss.
  let origin = if siteLink.len > 0: originOf(siteLink) else: originOf(feedUrl)
  if origin.len == 0: return none(FavBytes)
  let client = newHttpClient(timeout = FavTimeoutMs)
  client.headers = newHttpHeaders({"User-Agent": FavUserAgent})
  try:
    let resp = client.request(origin & "/favicon.ico", HttpGet)
    let code = resp.code.int
    if code != 200 and code != 301 and code != 302: return none(FavBytes)
    let body = resp.body
    if body.len < 50: return none(FavBytes)
    some(FavBytes(bytes: body, ext: ctToExt(resp.headers.getOrDefault("Content-Type"))))
  except CatchableError:
    none(FavBytes)
  finally:
    client.close()

proc resolveHref(origin, href: string): string =
  let h = href.strip()
  if h.startsWith("http://") or h.startsWith("https://"): return h
  if h.startsWith("//"): return "https:" & h
  if h.startsWith("/"): return origin & h
  origin & "/" & h

proc findIconHref(html, origin: string): string =
  ## Plain-string search for <link rel="icon" href="...">. No regex dep.
  let lower = html.toLowerAscii()
  var pos = 0
  while true:
    let ls = lower.find("<link", pos)
    if ls < 0: break
    let le = lower.find(">", ls)
    if le < 0: break
    let tag = lower[ls..le]
    pos = le + 1
    if ("icon" in tag or "shortcut icon" in tag) and "href" in tag:
      let hp = tag.find("href")
      if hp < 0: continue
      let rest = tag[hp + 4 ..^ 1].strip()
      if rest.len > 1 and rest[0] == '=':
        let val = rest[1..^1].strip()
        if val.len > 0 and (val[0] == '"' or val[0] == '\''):
          let q = val[0]
          let eq = val.find(q, 1)
          if eq > 0: return resolveHref(origin, val[1 ..< eq])
  ""

proc fetchFaviconAsync*(siteLink, feedUrl: string): Future[Option[FavBytes]] {.async.} =
  ## Async favicon fetch in the server event loop. Tries /favicon.ico, then
  ## parses the homepage HTML for <link rel="icon">. Can't deadlock (async).
  let origin = if siteLink.len > 0: originOf(siteLink) else: originOf(feedUrl)
  if origin.len == 0: return none(FavBytes)
  let client = newAsyncHttpClient()
  client.headers = newHttpHeaders({"User-Agent": FavUserAgent})
  try:
    # 1) direct /favicon.ico
    block tryDirect:
      let resp = await client.request(origin & "/favicon.ico", HttpGet)
      let code = resp.code.int
      if code == 200 or code == 301 or code == 302:
        let body = await resp.body
        if body.len >= 50:
          return some(FavBytes(bytes: body, ext: ctToExt(resp.headers.getOrDefault("Content-Type"))))
    # 2) parse homepage HTML for <link rel="icon">
    let htmlResp = await client.request(origin & "/", HttpGet)
    let htmlCode = htmlResp.code.int
    if htmlCode == 200:
      let html = await htmlResp.body
      let href = findIconHref(html, origin)
      if href.len > 0:
        let iconResp = await client.request(href, HttpGet)
        if iconResp.code.int == 200:
          let body = await iconResp.body
          if body.len >= 50:
            return some(FavBytes(bytes: body, ext: ctToExt(iconResp.headers.getOrDefault("Content-Type"))))
  except CatchableError:
    discard
  finally:
    client.close()
  none(FavBytes)

proc faviconHash*(origin: string): string =
  ## Stable per-site filename stem (FNV-1a hash → hex, no deprecated sha1 dep).
  var h: uint64 = 14695981039346656037'u64
  for c in origin:
    h = h xor uint64(c)
    h = h * 1099511628211'u64
  result = h.toHex().toLowerAscii()

proc saveFavicon*(fav: FavBytes; origin: string; dir = "favicons"): string =
  ## Save bytes to {dir}/{hash}.{ext}; create dir if needed. Returns the URL
  ## path "/favicons/{hash}.{ext}" to store in the feeds table + serve.
  createDir(dir)
  let stem = faviconHash(origin)
  let path = dir & "/" & stem & "." & fav.ext
  writeFile(path, fav.bytes)
  "/favicons/" & stem & "." & fav.ext
