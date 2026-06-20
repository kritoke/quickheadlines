## HTTP server - std/asynchttpserver (no new dep). Serves the frozen API.md
## read endpoints from the SQLite stores. Routing is explicit path+method
## matching; JSON shapes come from dtos.nim. Background write jobs (refresh,
## clustering) land in P3.10; this is the runnable read API.

import std/[asynchttpserver, asyncdispatch, json, uri, strutils, tables, options]
import ../types
import ../storage/[feed_store, item_store]
import ./dtos
import ./assets

type
  ServerCtx* = ref object
    config*: Config
    feedStore*: SqliteFeedStore
    itemStore*: SqliteItemStore
    startedAtMs*: int64

proc queryParams(q: string): Table[string, string] =
  for kv in q.split('&'):
    if kv.len == 0: continue
    let parts = kv.split('=', maxsplit = 1)
    if parts.len == 2:
      result[parts[0]] = decodeUrl(parts[1])
    else:
      result[parts[0]] = ""

proc intParam(p: Table[string, string]; key: string; dflt: int): int =
  if key in p:
    try: p[key].parseInt() except ValueError: dflt
  else: dflt

proc jsonHeaders(): HttpHeaders =
  newHttpHeaders({"Content-Type": "application/json"})

proc plainTextHeaders(): HttpHeaders =
  newHttpHeaders({"Content-Type": "text/plain"})

proc handle(ctx: ServerCtx; req: Request): Future[void] {.async.} =
  let path = req.url.path
  let verb = req.reqMethod
  let q = queryParams(req.url.query)

  if verb != HttpGet:
    await req.respond(Http405, $(%*{"error": "method not allowed"}), jsonHeaders())
    return

  # API + SPA routing. API routes are matched exactly; everything else is a
  # static asset (embedded) or, failing that, the SPA index.html fallback
  # (client-side routing).
  if not path.startsWith("/api/"):
    if path == "/version":
      await req.respond(Http200, $ctx.startedAtMs, plainTextHeaders())
      return
    let a = if path == "/": some(indexAsset()) else: getAsset(path)
    let asset = if a.isSome: a.get else: indexAsset()   # SPA fallback
    await req.respond(Http200, asset.content,
                      newHttpHeaders({"Content-Type": asset.contentType,
                                       "Cache-Control": "no-cache"}))
    return

  case path
  of "/api/timeline":
    let limit = q.intParam("limit", 35)
    let offset = q.intParam("offset", 0)
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
    # Hydrate-on-first-load (long-poll): if the DB cache is still empty (the
    # background refresh hasn't committed yet), wait briefly for it to populate
    # so the SPA's initial request returns real data instead of an empty list
    # it would never re-fetch (no WebSocket push yet - P3.7). sleepAsync yields
    # the event loop, so other requests are still served while we wait.
    var listed = ctx.feedStore.listFeeds()
    if listed.isOk:
      for _ in 0 ..< 30:                       # up to ~30s
        if listed.feeds.len > 0: break
        await sleepAsync(1000)
        listed = ctx.feedStore.listFeeds()
        if not listed.isOk: break
    if not listed.isOk:
      await req.respond(Http500, $(%*{"error": "feeds read failed"}), jsonHeaders())
      return
    var feedNodes: seq[JsonNode]
    for f in listed.feeds:
      let items = ctx.feedStore.recentItems(f.id, ctx.config.itemLimit)
      feedNodes.add(feedJson(f, items, ctx.feedStore.countItems(f.id)))
    let activeTab = q.getOrDefault("tab", "all")
    await req.respond(Http200, $(%*{
      "tabs": tabsJson(ctx.config.tabs)["tabs"],
      "active_tab": %activeTab, "feeds": %feedNodes,
      "software_releases": newJArray(),
      "is_clustering": false,
      "updated_at": %ctx.startedAtMs}), jsonHeaders())

  of "/api/status":
    await req.respond(Http200, $statusJson(false, 0), jsonHeaders())

  of "/api/health":
    await req.respond(Http200, $(%*{"status": "ok"}), jsonHeaders())

  of "/api/version":
    await req.respond(Http200, $versionJson(ctx.startedAtMs), jsonHeaders())

  else:
    await req.respond(Http404, $(%*{"error": "not found"}), jsonHeaders())

proc serve*(ctx: ServerCtx; port = 8080) =
  ## Start the HTTP server (blocks the caller via waitFor).
  let server = newAsyncHttpServer()
  echo "QuickHeadlines (Nim) listening on http://0.0.0.0:" & $port
  waitFor server.serve(Port(port), proc(req: Request): Future[void] {.async.} =
    try: await ctx.handle(req)
    except CatchableError as e:
      try: await req.respond(Http500, $(%*{"error": %e.msg}), jsonHeaders())
      except CatchableError: discard)
  # server.serve returns only on shutdown
