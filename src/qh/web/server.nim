## HTTP server - std/asynchttpserver (no new dep). Serves the frozen API.md
## read endpoints from the SQLite stores, the embedded SPA, AND a minimal
## WebSocket push (/api/ws) so the SPA hydrates the moment feeds land in the
## DB (replaces long-polling - the long-term fix).
##
## Concurrency: the HTTP handlers + the WS client registry + the broadcast
## watcher all run on the single async event-loop thread (cooperative), so the
## registry needs no lock. The only cross-thread bit is `ctx.dirty` (an Atomic-
## Bool ref set by the refresh supervisor thread).

import std/[asynchttpserver, asyncdispatch, asyncnet, json, uri, strutils, tables, options, atomics, sequtils]
import ../types
import ../storage/[feed_store, item_store]
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

  # ---- WebSocket upgrade (before the GET-only / static checks) ----
  if path == "/api/ws" and verb == HttpGet:
    await req.wsSession()
    return

  if verb != HttpGet:
    await req.respond(Http405, $(%*{"error": "method not allowed"}), jsonHeaders())
    return

  if not path.startsWith("/api/"):
    if path == "/version":
      await req.respond(Http200, $ctx.startedAtMs, plainTextHeaders()); return
    let a = if path == "/": some(indexAsset()) else: getAsset(path)
    let asset = if a.isSome: a.get else: indexAsset()   # SPA fallback
    await req.respond(Http200, asset.content,
                      newHttpHeaders({"Content-Type": asset.contentType, "Cache-Control": "no-cache"}))
    return

  case path
  of "/api/timeline":
    let limit = q.intParam("limit", 35); let offset = q.intParam("offset", 0)
    let days = q.intParam("days", 7)
    let r = ctx.itemStore.findTimeline(limit, offset, days)
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
    var feedNodes: seq[JsonNode]
    for f in listed.feeds:
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
  ## Periodically push a WS 'feed_update' when the refresh supervisor signals.
  while true:
    await sleepAsync(1000)
    if wsClients.len > 0 and ctx.dirty[].load():
      ctx.dirty[].store(false)
      let snap = wsClients                       # copy (mutation-safe over awaits)
      var alive: seq[AsyncSocket] = @[]
      for c in snap:
        var ok = true
        try: await sendWsText(c, "{\"type\":\"feed_update\"}")
        except CatchableError: ok = false
        if ok: alive.add(c)
      wsClients = alive                          # drop dead clients

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
