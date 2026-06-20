## HTTP server - std/asynchttpserver (no new dep). Serves the frozen API.md
## read endpoints from the SQLite stores, the embedded SPA, AND a minimal
## WebSocket push (/api/ws) so the SPA hydrates the moment feeds land in the
## DB (replaces long-polling - the long-term fix).
##
## Concurrency: the HTTP handlers + the WS client registry + the broadcast
## watcher all run on the single async event-loop thread (cooperative), so the
## registry needs no lock. The only cross-thread bit is `ctx.dirty` (an Atomic-
## Bool ref set by the refresh supervisor thread).

import std/[asynchttpserver, asyncdispatch, asyncnet, json, uri, strutils, tables, options, atomics, sequtils, os]
import ../types
import ../storage/[feed_store, item_store]
import ../fetcher/favicon
import ../security/[auth, rate_limiter]
import ./dtos
import ./assets
import ./ws

type
  ServerCtx* = ref object
    config*: Config
    feedStore*: SqliteFeedStore
    itemStore*: SqliteItemStore
    startedAtMs*: int64
    dirty*: ref Atomic[bool]     # set by refresh supervisor -> watcher broadcasts
    rateLimiter*: RateLimiter

# WS client registry (event-loop thread only - no lock needed).
var wsClients: seq[AsyncSocket] = @[]

proc queryParams(q: string): Table[string, string] =
  for kv in q.split('&'):
    if kv.len == 0: continue
    let parts = kv.split('=', maxsplit = 1)
    if parts.len == 2: result[parts[0]] = decodeUrl(parts[1])
    else: result[parts[0]] = ""

proc intParam(p: Table[string, string]; key: string; dflt: int): int =
  if key in p:
    try: p[key].parseInt() except ValueError: dflt
  else: dflt

proc jsonHeaders(): HttpHeaders = newHttpHeaders({"Content-Type": "application/json"})
proc plainTextHeaders(): HttpHeaders = newHttpHeaders({"Content-Type": "text/plain"})

# ---- WebSocket session: handshake, register, hold until close ----
proc wsSession(req: Request): Future[void] {.async.} =
  let key = req.headers.getOrDefault("Sec-WebSocket-Key")
  if key.len == 0:
    await req.respond(Http400, $(%*{"error": "missing Sec-WebSocket-Key"}), jsonHeaders())
    return
  let accept = wsAcceptKey(key)
  await req.client.send(
    "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n" &
    "Connection: Upgrade\r\nSec-WebSocket-Accept: " & accept & "\r\n\r\n")
  wsClients.add(req.client)                       # register for broadcasts
  try:
    while true:
      let data = await req.client.recv(4096)       # detect close; discard frames
      if data.len == 0: break
  except CatchableError:
    discard
  wsClients.keepItIf(it != req.client)            # unregister on close

proc handle(ctx: ServerCtx; req: Request): Future[void] {.async.} =
  let path = req.url.path
  let verb = req.reqMethod
  let q = queryParams(req.url.query)

  # ---- rate limit by peer IP (P3.8) ----
  if ctx.rateLimiter != nil:
    let (peerIp, _) = req.client.getPeerAddr()
    if not ctx.rateLimiter.isAllowed(peerIp):
      await req.respond(Http429,
        $(%*{"error": "rate limited", "retry_after": 60}),
        jsonHeaders())
      return

  # ---- WebSocket upgrade (before the GET-only / static checks) ----
  if path == "/api/ws" and verb == HttpGet:
    await req.wsSession()
    return

  if verb != HttpGet:
    await req.respond(Http405, $(%*{"error": "method not allowed"}), jsonHeaders())
    return

  if not path.startsWith("/api/"):
    if path == "/version":
      await req.respond(Http200, $ctx.startedAtMs, plainTextHeaders())
      return
    # Runtime favicon files (written by a favicon supervisor). Only serve the
    # basename from the favicons/ dir; reject anything that looks like traversal.
    # Missing file -> fall back to the embedded favicon.svg (no 404 spam).
    if path.startsWith("/favicons/"):
      let name = path[10..^1]                      # strip "/favicons/" (10 chars)
      if name.len > 0 and "/" notin name and ".." notin name:
        let fp = "favicons" / name
        if fileExists(fp):
          let ext = fp.rsplit('.', maxsplit = 1)
          let ct = if ext.len == 2 and ext[1] == "png": "image/png"
                   elif ext.len == 2 and ext[1] == "svg": "image/svg+xml"
                   else: "image/x-icon"
          await req.respond(Http200, readFile(fp),
                            newHttpHeaders({"Content-Type": ct, "Cache-Control": "public, max-age=604800"}))
          return
      # Fallback: embedded favicon.svg (avoids a sea of 404s for missing icons).
      let fb = getAsset("/favicon.svg")
      let asset = if fb.isSome: fb.get else: indexAsset()
      await req.respond(Http200, asset.content,
                        newHttpHeaders({"Content-Type": asset.contentType, "Cache-Control": "no-cache"}))
      return
    let a = if path == "/": some(indexAsset()) else: getAsset(path)
    let asset = if a.isSome: a.get else: indexAsset()   # SPA fallback
    await req.respond(Http200, asset.content,
                      newHttpHeaders({"Content-Type": asset.contentType, "Cache-Control": "no-cache"}))
    return

  case path
  of "/api/timeline":
    let limit = q.intParam("limit", 35); let offset = q.intParam("offset", 0)
    let days = q.intParam("days", 7)
    let tab = q.getOrDefault("tab", "")
    # Build allowed feed URLs for this tab (empty = all feeds).
    var allowedUrls: seq[string] = @[]
    if tab.len > 0 and tab.toLowerAscii() != "all":
      for t in ctx.config.tabs:
        if t.name.toLowerAscii() == tab.toLowerAscii():
          for f in t.feeds: allowedUrls.add(f.url)
          break
    let r = ctx.itemStore.findTimeline(limit, offset, days, allowedUrls)
    if r.isOk:
      await req.respond(Http200, $timelineJson(r.entries, r.total, limit), jsonHeaders())
    else:
      await req.respond(Http500, $(%*{"error": "timeline read failed"}), jsonHeaders())

  of "/api/config":
    await req.respond(Http200, $configJson(ctx.config), jsonHeaders())

  of "/api/tabs":
    await req.respond(Http200, $tabsJson(ctx.config.tabs), jsonHeaders())

  of "/api/feeds":
    # Short grace (2s) for instant landers; real first-load hydration is via the
    # WS feed_update push (handled by the watcher). Subsequent calls are instant.
    var listed = ctx.feedStore.listFeeds()
    if listed.isOk and listed.feeds.len == 0:
      for _ in 0..<2:
        await sleepAsync(1000); listed = ctx.feedStore.listFeeds()
        if not listed.isOk or listed.feeds.len > 0: break
    if not listed.isOk:
      await req.respond(Http500, $(%*{"error": "feeds read failed"}), jsonHeaders()); return
    let tab = q.getOrDefault("tab", "all").toLowerAscii()
    # Build tab→urls map from config for filtering.
    var tabUrls: Table[string, seq[string]]
    for t in ctx.config.tabs:
      var urls: seq[string]
      for f in t.feeds: urls.add(f.url)
      tabUrls[t.name.toLowerAscii()] = urls
    var feedNodes: seq[JsonNode]
    for f in listed.feeds:
      # Filter: if a specific tab is requested, only include feeds whose URL is
      # in that tab's config feed list. "all" includes everything.
      if tab != "all":
        let urls = tabUrls.getOrDefault(tab, @[])
        if f.url notin urls: continue
      let items = ctx.feedStore.recentItems(f.id, ctx.config.itemLimit)
      feedNodes.add(feedJson(f, items, ctx.feedStore.countItems(f.id)))
    let activeTab = q.getOrDefault("tab", "all")
    await req.respond(Http200, $(%*{
      "tabs": tabsJson(ctx.config.tabs)["tabs"], "active_tab": %activeTab,
      "feeds": %feedNodes, "software_releases": newJArray(),
      "is_clustering": false, "updated_at": %ctx.startedAtMs}), jsonHeaders())

  of "/api/status":
    await req.respond(Http200, $statusJson(false, 0), jsonHeaders())

  of "/api/health":
    await req.respond(Http200, $(%*{"status": "ok"}), jsonHeaders())

  of "/api/version":
    await req.respond(Http200, $versionJson(ctx.startedAtMs), jsonHeaders())

  else:
    await req.respond(Http404, $(%*{"error": "not found"}), jsonHeaders())

proc feedWatcher(ctx: ServerCtx): Future[void] {.async.} =
  ## Periodically push a WS 'feed_update' when feeds change, AND progressively
  ## fetch missing favicons (async, in the event loop - can't deadlock the feed
  ## worker pool the way a threaded sync fetcher did).
  var tick = 0
  while true:
    await sleepAsync(1000)
    inc tick
    # WS broadcast on dirty.
    if wsClients.len > 0 and ctx.dirty[].load():
      ctx.dirty[].store(false)
      let snap = wsClients
      var alive: seq[AsyncSocket] = @[]
      for c in snap:
        var ok = true
        try: await sendWsText(c, "{\"type\":\"feed_update\"}")
        except CatchableError: ok = false
        if ok: alive.add(c)
      wsClients = alive
    # Favicon: fetch several missing icons concurrently every 3s (async,
    # isolated in the event loop - can't deadlock). Parallel, not sequential.
    if tick mod 3 == 0:
      let missing = ctx.feedStore.feedsMissingFavicon(8)
      if missing.len > 0:
        var futures: seq[Future[Option[FavBytes]]] = @[]
        for (id, siteLink, url) in missing:
          futures.add fetchFaviconAsync(siteLink, url)
        let results = await all(futures)
        var saved, failed: int
        var failUrls: seq[string]
        for i in 0 ..< results.len:
          if results[i].isSome:
            try:
              let (id, siteLink, url) = missing[i]
              let origin = if siteLink.len > 0: siteLink else: url
              let path = saveFavicon(results[i].get, origin)
              ctx.feedStore.setFavicon(id, path)
              ctx.dirty[].store(true)
              inc saved
            except CatchableError:
              inc failed
              failUrls.add(missing[i][2])
          else:
            inc failed
            failUrls.add(missing[i][2])
        let failMsg = if failUrls.len > 0: " failed_urls=" & failUrls.join(",") else: ""
        echo "[favicon] tick=", tick, " tried=", missing.len, " saved=", saved, " failed=", failed, failMsg

proc serve*(ctx: ServerCtx; port = 8080) =
  ## Start the HTTP server (blocks) + the WS-broadcast watcher on one event loop.
  let server = newAsyncHttpServer()
  echo "QuickHeadlines (Nim) listening on http://0.0.0.0:" & $port
  asyncCheck feedWatcher(ctx)                    # runs concurrently with the server
  # handle() touches the wsClients module var (via wsSession), so it isn't
  # provably gcsafe; serve()'s callback must be gcsafe. The server is
  # single-threaded (one event loop) so assert gcsafe here (ORC is runtime-safe).
  proc cb(req: Request): Future[void] {.async, gcsafe.} =
    {.cast(gcsafe).}:
      try: await ctx.handle(req)
      except CatchableError as e:
        try: await req.respond(Http500, $(%*{"error": %e.msg}), jsonHeaders())
        except CatchableError: discard
  waitFor server.serve(Port(port), cb)
