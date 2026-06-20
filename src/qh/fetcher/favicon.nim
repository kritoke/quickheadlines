## Simple favicon fetcher - the 80%-of-sites core (NOT a full vug.cr port).
## Just GET {origin}/favicon.ico. Deliberately avoids std/re (regex) because the
## re module is not safe inside the fetch worker threads (it hung the refresh).
## The HTML <link rel=icon> parse can be added later via a non-threaded path.

import std/[httpclient, asyncdispatch, uri, strutils, sha1, os, options]
import ../types

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

proc fetchFaviconAsync*(siteLink, feedUrl: string): Future[Option[FavBytes]] {.async.} =
  ## Async version - runs in the server event loop (sync httpclient's timeout
  ## doesn't bound connect/DNS in a thread, which deadlocked the feed worker
  ## pool). Best-effort /favicon.ico. A hung connect blocks only this one
  ## coroutine, not the event loop - no deadlock.
  let origin = if siteLink.len > 0: originOf(siteLink) else: originOf(feedUrl)
  if origin.len == 0: return none(FavBytes)
  let client = newAsyncHttpClient()
  client.headers = newHttpHeaders({"User-Agent": FavUserAgent})
  try:
    let resp = await client.request(origin & "/favicon.ico", HttpGet)
    let code = resp.code.int
    if code != 200 and code != 301 and code != 302: return none(FavBytes)
    let body = await resp.body
    if body.len < 50: return none(FavBytes)
    return some(FavBytes(bytes: body, ext: ctToExt(resp.headers.getOrDefault("Content-Type"))))
  except CatchableError:
    return none(FavBytes)
  finally:
    client.close()

proc faviconHash*(origin: string): string =
  ($secureHash(origin)).toLowerAscii()

proc saveFavicon*(fav: FavBytes; origin: string; dir = "favicons"): string =
  ## Save bytes to {dir}/{hash}.{ext}; create dir if needed. Returns the URL
  ## path "/favicons/{hash}.{ext}" to store in the feeds table + serve.
  createDir(dir)
  let stem = faviconHash(origin)
  let path = dir & "/" & stem & "." & fav.ext
  writeFile(path, fav.bytes)
  "/favicons/" & stem & "." & fav.ext
