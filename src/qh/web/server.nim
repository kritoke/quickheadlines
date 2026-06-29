## HTTP server - std/asynchttpserver (no new dep). Serves the frozen API.md
## read endpoints from the SQLite stores, the embedded SPA, AND a minimal
## WebSocket push (/api/ws) so the SPA hydrates the moment feeds land in the
## DB (replaces long-polling - the long-term fix).
##
## Concurrency: the HTTP handlers + the WS client registry + the broadcast
## watcher all run on the single async event-loop thread (cooperative), so the
## registry needs no lock. The only cross-thread bit is `ctx.dirty` (an Atomic-
## Bool ref set by the refresh supervisor thread).

import std/[asynchttpserver, asyncdispatch, asyncnet, json, uri, strutils, tables, options, atomics, sequtils, os, algorithm, net, httpclient, re, times]
import ../types
import ../storage/[feed_store, item_store, content_store]
import ../fetcher/favicon
import ../color/extractor as colorExtractor
import ../security/[rate_limiter, auth, proxy_validator]
import ./dtos
import ./assets
import ./ws
import ./ws_broadcaster

type
  WsClient = object
    socket: AsyncSocket
    ip: string
    createdAt: float       # epoch seconds
    lastActivity: float    # epoch seconds

  ServerCtx* = ref object
    config*: Config
    feedStore*: SqliteFeedStore
    itemStore*: SqliteItemStore
    contentStore*: SqliteContentStore
    startedAtMs*: int64
    dirty*: ref Atomic[bool]     # set by refresh supervisor -> watcher broadcasts
    isClustering*: ref Atomic[bool]  # set by cluster supervisor during clustering
    triggerCluster*: ref Atomic[bool]  # set by /api/cluster to trigger immediate run
    rateLimiter*: RateLimiter
    proxyValidator*: ProxyValidator
    broadcaster*: WsBroadcaster       # WS connection management + event broadcasting
    faviconFailures: Table[string, int]  # favicon failure backoff tracking

proc addSecurityHeaders(h: HttpHeaders) =
  h["X-Content-Type-Options"] = "nosniff"
  h["X-Frame-Options"] = "DENY"
  h["Referrer-Policy"] = "strict-origin-when-cross-origin"
  h["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"

proc jsonHeaders(): HttpHeaders =
  let h = newHttpHeaders({"Content-Type": "application/json", "Cache-Control": "no-cache, no-store, must-revalidate"})
  addSecurityHeaders(h)
  h

proc plainTextHeaders(): HttpHeaders =
  let h = newHttpHeaders({"Content-Type": "text/plain"})
  addSecurityHeaders(h)
  h

# ---- WebSocket session: handshake, register, hold until close ----
proc wsSession(ctx: ServerCtx; req: Request): Future[void] {.async.} =
  let key = req.headers.getOrDefault("Sec-WebSocket-Key")
  if key.len == 0:
    await req.respond(Http400, $(%*{"error": "missing Sec-WebSocket-Key"}), jsonHeaders())
    return
  let (peerIp, _) = req.client.getPeerAddr()
  let (canConnect, reason) = ctx.broadcaster.canAccept(peerIp)
  if not canConnect:
    await req.respond(Http429, $(%*{"error": reason}), jsonHeaders())
    return
  let accept = wsAcceptKey(key)
  await req.client.send(
    "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n" &
    "Connection: Upgrade\r\nSec-WebSocket-Accept: " & accept & "\r\n\r\n")
  ctx.broadcaster.register(req.client, peerIp)
  try:
    while true:
      let data = await req.client.recv(4096)
      if data.len == 0: break            # client closed the connection
      ctx.broadcaster.touch(req.client)
  except CatchableError:
    discard                              # socket died; drop it below
  # Always remove + close so we never leak the FD or a broadcaster slot.
  ctx.broadcaster.remove(req.client)
  try: req.client.close() except CatchableError: discard

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

proc handle(ctx: ServerCtx; req: Request): Future[void] {.async.} =
  let path = req.url.path
  let verb = req.reqMethod
  let q = queryParams(req.url.query)

  # ---- rate limit API requests only (not static assets) ----
  if ctx.rateLimiter != nil and path.startsWith("/api/"):
    let (peerIp, _) = req.client.getPeerAddr()
    # Per-endpoint rate limits (port of Crystal's per-controller limits).
    let endpointLimit = case path
      of "/api/feeds": 600
      of "/api/timeline": 360
      of "/api/config": 600
      of "/api/tabs": 600
      of "/api/feed_more": 30
      of "/api/clusters": 120
      of "/api/content": 120
      of "/api/proxy-image": 30
      of "/api/status": 60
      of "/api/health": 60
      of "/api/version": 60
      of "/api/ws": 10
      else: 1000  # admin + unknown endpoints
    let rateKey = path & ":" & peerIp
    if not ctx.rateLimiter.isAllowed(rateKey, endpointLimit):
      let retrySec = ctx.rateLimiter.retryAfter(rateKey, endpointLimit)
      await req.respond(Http429,
        $(%*{"error": "rate limited", "retry_after": retrySec}),
        newHttpHeaders({"Content-Type": "application/json",
                        "Retry-After": $retrySec}))
      return

  # ---- POST endpoints (admin auth required) ----
  if verb == HttpPost:
    if path == "/api/header_color":
      if not checkAdminAuth(req.headers.getOrDefault("Authorization")):
        await req.respond(Http401, $(%*{"error": "unauthorized"}), jsonHeaders()); return
      try:
        let body = parseJson(req.body)
        let feedUrl = body{"feed_url"}.getStr("")
        let color = body{"color"}.getStr("")
        let textColor = body{"text_color"}.getStr("")
        if feedUrl.len == 0:
          await req.respond(Http400, $(%*{"error": "feed_url required"}), jsonHeaders()); return
        let listed = ctx.feedStore.listFeeds()
        if listed.isOk:
          for f in listed.feeds:
            if f.url == feedUrl:
              ctx.feedStore.setHeaderColor(f.id, color, textColor)
              ctx.dirty[].store(true)
              break
        await req.respond(Http200, $(%*{"status": "ok"}), jsonHeaders())
      except CatchableError:
        await req.respond(Http400, $(%*{"error": "invalid json"}), jsonHeaders())
      return
    if path == "/api/cluster":
      if not checkAdminAuth(req.headers.getOrDefault("Authorization")):
        await req.respond(Http401, $(%*{"error": "unauthorized"}), jsonHeaders()); return
      if ctx.triggerCluster != nil:
        ctx.triggerCluster[].store(true)
      await req.respond(Http200, $(%*{"status": "ok", "message": "clustering triggered"}), jsonHeaders())
      return
    if path == "/api/admin":
      if not checkAdminAuth(req.headers.getOrDefault("Authorization")):
        await req.respond(Http401, $(%*{"error": "unauthorized"}), jsonHeaders()); return
      await req.respond(Http200, $(%*{"status": "ok"}), jsonHeaders())
      return
    await req.respond(Http405, $(%*{"error": "method not allowed"}), jsonHeaders())
    return

  # ---- WebSocket upgrade (before the GET-only / static checks) ----
  if path == "/api/ws" and verb == HttpGet:
    await ctx.wsSession(req)
    return

  if verb != HttpGet:
    await req.respond(Http405, $(%*{"error": "method not allowed"}), jsonHeaders())
    return

  if not path.startsWith("/api/"):
    if path == "/version":
      await req.respond(Http200, $ctx.startedAtMs, plainTextHeaders())
      return
    if path == "/robots.txt":
      await req.respond(Http200, "User-agent: *\nDisallow: /", newHttpHeaders({"Content-Type": "text/plain"}))
      return
    if path == "/.well-known" or path.startsWith("/.well-known/"):
      await req.respond(Http404, "", plainTextHeaders())
      return
    if path == "/apple-touch-icon.png":
      await req.respond(Http404, "", plainTextHeaders())
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

  # ---- Dynamic-path endpoints (must check before the case block) ----
  if path.startsWith("/api/clusters/") and path.endsWith("/items"):
    let idStr = path[14 .. ^7]  # strip "/api/clusters/" and "/items"
    try:
      let clusterId = idStr.parseInt().int64
      let items = ctx.itemStore.getClusterItems(clusterId)
      var clusterNode = %*{"id": %idStr, "items": newJArray()}
      for it in items: clusterNode["items"].add(timelineItemJson(it))
      await req.respond(Http200, $clusterNode, jsonHeaders())
    except ValueError:
      await req.respond(Http400, $(%*{"error": "invalid cluster id"}), jsonHeaders())
    return

  if path == "/api/favicon.png":
    let url = q.getOrDefault("url", "")
    if url.len == 0:
      await req.respond(Http400, $(%*{"error": "url required"}), jsonHeaders()); return
    let listed = ctx.feedStore.listFeeds()
    if listed.isOk:
      for f in listed.feeds:
        if f.url == url and f.favicon.len > 0:
          let fp = if f.favicon.startsWith("/favicons/"): "favicons" & f.favicon[9..^1]
                   elif f.favicon.startsWith("favicons/"): f.favicon
                   else: "favicons" / f.favicon
          if fileExists(fp):
            let ext = fp.rsplit('.', maxsplit = 1)
            let ct = if ext.len == 2 and ext[1] == "png": "image/png"
                     elif ext.len == 2 and ext[1] == "svg": "image/svg+xml"
                     else: "image/x-icon"
            await req.respond(Http200, readFile(fp), newHttpHeaders({"Content-Type": ct, "Cache-Control": "public, max-age=86400"}))
            return
    await req.respond(Http404, $(%*{"error": "favicon not found"}), jsonHeaders())
    return

  if path == "/api/proxy-image":
    let url = q.getOrDefault("url", "")
    let maxBytes = q.intParam("max", 2 * 1024 * 1024)  # default 2MB
    if url.len == 0:
      await req.respond(Http400, $(%*{"error": "url required"}), jsonHeaders()); return
    if maxBytes > 10 * 1024 * 1024:
      await req.respond(Http400, $(%*{"error": "max too large (10MB limit)"}), jsonHeaders()); return
    if ctx.proxyValidator == nil:
      await req.respond(Http500, $(%*{"error": "proxy not configured"}), jsonHeaders()); return
    let validation = ctx.proxyValidator.validate(url)
    if not validation.isOk:
      await req.respond(Http403, $(%*{"error": "proxy validation failed"}), jsonHeaders()); return
    try:
      let parsed = parseUri(url)
      var resolvedUrl = parsed.scheme & "://" & validation.resolvedIp & parsed.path
      if parsed.query.len > 0: resolvedUrl = resolvedUrl & "?" & parsed.query
      let client = newHttpClient(timeout = 10000, maxRedirects = 3)
      client.headers = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (compatible; QuickHeadlines/1.0)",
        "Accept": "image/*",
        "Host": parsed.hostname})
      let resp = client.request(resolvedUrl, HttpGet)
      client.close()
      if resp.code.int != 200:
        await req.respond(Http502, $(%*{"error": "upstream error"}), jsonHeaders()); return
      var ct = "image/png"
      if resp.headers.hasKey("Content-Type"): ct = resp.headers["Content-Type"]
      if not ct.startsWith("image/"):
        await req.respond(Http403, $(%*{"error": "not an image"}), jsonHeaders()); return
      if resp.body.len > maxBytes:
        await req.respond(Http413, $(%*{"error": "image too large"}), jsonHeaders()); return
      await req.respond(Http200, resp.body, newHttpHeaders({
        "Content-Type": ct, "Cache-Control": "public, max-age=86400",
        "X-Content-Type-Options": "nosniff"}))
    except CatchableError:
      await req.respond(Http502, $(%*{"error": "proxy fetch failed"}), jsonHeaders())
    return

  # ---- Static API endpoints ----
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
    # Long-poll: if DB is empty (first load), wait for the refresh supervisor
    # to populate feeds. Polls every 500ms for up to 30s. Once feeds exist,
    # returns immediately. This ensures the SPA gets real data on first load
    # even without WebSocket push (WS provides progressive updates later).
    var listed = ctx.feedStore.listFeeds()
    if listed.isOk and listed.feeds.len == 0:
      for _ in 0 ..< 60:
        await sleepAsync(500)
        listed = ctx.feedStore.listFeeds()
        if listed.isOk and listed.feeds.len > 0:
          break
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
    var swNodes: seq[JsonNode]
    for f in listed.feeds:
      # Software releases feed is included only in the "all" tab view.
      if f.url == "software://releases":
        if tab == "all":
          let items = ctx.feedStore.recentItems(f.id, ctx.config.itemLimit)
          swNodes.add(feedJson(f, items, ctx.feedStore.countItems(f.id)))
        continue
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
      "feeds": %feedNodes, "software_releases": %swNodes,
      "is_clustering": false, "updated_at": %ctx.startedAtMs}), jsonHeaders())

  of "/api/status":
    let clustering = if ctx.isClustering != nil: ctx.isClustering[].load() else: false
    await req.respond(Http200, $statusJson(clustering, 0), jsonHeaders())

  of "/api/health":
    # Verify DB connectivity.
    let dbOk = ctx.feedStore.listFeeds().isOk
    let status = if dbOk: "ok" else: "degraded"
    let code = if dbOk: Http200 else: Http503
    await req.respond(code, $(%*{"status": status}), jsonHeaders())

  of "/api/version":
    await req.respond(Http200, $versionJson(ctx.startedAtMs), jsonHeaders())

  of "/api/content":
    let link = q.getOrDefault("link", "")
    if link.len == 0:
      await req.respond(Http400, $(%*{"error": "missing link parameter"}), jsonHeaders())
    elif ctx.contentStore == nil:
      await req.respond(Http500, $(%*{"error": "content store not configured"}), jsonHeaders())
    else:
      let article = ctx.contentStore.getArticle(link)
      if article.link.len == 0:
        await req.respond(Http200, $(%*{
          "error": "Full article not available. Content is fetched from RSS feeds which typically contain only summaries, not full articles.",
          "is_summary": false, "article_url": %link}), jsonHeaders())
      else:
        # Check if content is summary-only (same heuristic as Crystal controller).
        let isSummary = article.content.len < 500 or
          article.content.toLowerAscii().contains(re"(read more|read full|subscribe|click here|sorry.*content)")
        await req.respond(Http200, $(%*{
          "content": %article.content, "content_type": %article.contentType,
          "is_summary": %isSummary, "article_url": %article.link}), jsonHeaders())

  # /api/feed_more?url=...&limit=10&offset=0 — more items for a specific feed.
  of "/api/feed_more":
    let url = q.getOrDefault("url", "")
    let limit = q.intParam("limit", 10)
    let offset = q.intParam("offset", 0)
    if url.len == 0:
      await req.respond(Http400, $(%*{"error": "url required"}), jsonHeaders())
    else:
      let r = ctx.itemStore.feedItems(url, limit, offset)
      if r.isOk:
        # Find the feed metadata.
        var feedNode = %*{"url": url, "title": "", "display_link": "", "site_link": "",
                          "favicon": "", "favicon_data": "", "header_color": newJNull(),
                          "header_text_color": newJNull(), "tab": "",
                          "items": %(r.entries.mapIt(timelineItemJson(it))),
                          "total_item_count": %r.total}
        let listed = ctx.feedStore.listFeeds()
        if listed.isOk:
          for f in listed.feeds:
            if f.url == url:
              feedNode["title"] = %f.title
              feedNode["display_link"] = %f.siteLink
              feedNode["site_link"] = %f.siteLink
              feedNode["favicon"] = jstrOr(f.favicon)
              feedNode["header_color"] = jstr(f.headerColor)
              feedNode["header_text_color"] = jstr(f.headerTextColor)
              break
        await req.respond(Http200, $feedNode, jsonHeaders())
      else:
        await req.respond(Http500, $(%*{"error": "feed_more failed"}), jsonHeaders())

  # /api/clusters — list all clusters with their items.
  of "/api/clusters":
    let limit = q.intParam("limit", 50)
    let offset = q.intParam("offset", 0)
    let clusterMap = ctx.itemStore.loadAllClusters()
    var clusterIds: seq[int64]
    for cid in clusterMap.keys: clusterIds.add(cid)
    clusterIds.sort()
    let slice = clusterIds[offset ..< min(offset + limit, clusterIds.len)]
    var clusterNodes: seq[JsonNode]
    for cid in slice:
      let members = clusterMap[cid]
      var representative = newJObject()
      var others: seq[JsonNode] = @[]
      for m in members:
        if m.representative: representative = timelineItemJson(m)
        else: others.add(timelineItemJson(m))
      clusterNodes.add(%*{
        "id": %($cid),
        "representative": representative,
        "others": %others,
        "cluster_size": %members.len
      })
    await req.respond(Http200, $(%*{
      "clusters": %clusterNodes,
      "total_count": %clusterIds.len}), jsonHeaders())

  else:
    await req.respond(Http404, $(%*{"error": "not found"}), jsonHeaders())

proc faviconWithTimeout(fut: Future[Option[FavBytes]]; timeoutMs: int):
    Future[Option[FavBytes]] {.async.} =
  ## Race a favicon fetch against a hard deadline.  The favicon fetcher hits
  ## many different site origins, some of which accept the TCP connection then
  ## never respond — and fetchFaviconAsync runs on the server's single event
  ## loop, so a single hanging host would stall the entire server (HTTP
  ## requests + WS pushes). Abandoning the future after timeoutMs keeps the
  ## event loop live; the underlying request may complete later and be GC'd.
  let timer = sleepAsync(timeoutMs)
  await fut or timer
  if fut.finished and not fut.failed:
    return fut.read()        # the resolved Option[FavBytes]
  return none(FavBytes)      # timed out or failed -> treat as no favicon

proc feedWatcher(ctx: ServerCtx): Future[void] {.async.} =
  ## Periodically push WS events when feeds change, AND progressively
  ## fetch missing favicons (async, in the event loop).
  var tick = 0
  while true:
    await sleepAsync(5000)  # 5s base interval (was 1s)
    inc tick

    # ---- WS broadcast on dirty flag ----
    if ctx.broadcaster.len > 0 and ctx.dirty[].load():
      ctx.dirty[].store(false)
      let sent = await ctx.broadcaster.broadcast(feedUpdateJson())
      if sent > 0: discard  # logged by broadcaster

    # ---- WS heartbeat every 30s ----
    if ctx.broadcaster.len > 0 and tick mod WsHeartbeatSec == 0:
      discard await ctx.broadcaster.broadcast(heartbeatJson())

    # ---- WS janitor every 5 min: clean stale connections ----
    if tick mod WsJanitorIntervalSec == 0 and ctx.broadcaster.len > 0:
      let removed = ctx.broadcaster.cleanupStale()
      if removed > 0:
        echo "[ws] janitor: removed ", removed, " stale connections (remaining=", ctx.broadcaster.len, ")"

    # ---- Favicon: fetch missing icons every 15s (3 ticks × 5s) ----
    if tick mod 3 == 0:
      # 1. Fetch missing favicons.
      let missing = ctx.feedStore.feedsMissingFavicon(8)
      if missing.len > 0:
        var futures: seq[Future[Option[FavBytes]]] = @[]
        for (id, siteLink, url) in missing:
          # Skip feeds that have failed recently (in-memory backoff).
          let failKey = url
          if failKey in ctx.faviconFailures and ctx.faviconFailures[failKey] >= 3:
            continue
          futures.add faviconWithTimeout(fetchFaviconAsync(siteLink, url), 15000)
        if futures.len > 0:
          let results = await all(futures)
          var saved, failed: int
          var failUrls: seq[string]
          for i in 0 ..< results.len:
            if results[i].isSome:
              try:
                let (id, siteLink, url) = missing[i]
                let origin = if siteLink.len > 0: siteLink else: url
                let fav = results[i].get
                let path = saveFavicon(fav, origin)
                ctx.feedStore.setFavicon(id, path)
                let theme = colorExtractor.extractTheme(fav.bytes)
                if theme.isSome:
                  let textColor = colorExtractor.selectTextColor(theme.get)
                  ctx.feedStore.setThemeColors(id, theme.get.bgColor, textColor, textColor)
                ctx.dirty[].store(true)
                inc saved
                # Clear failure count on success.
                ctx.faviconFailures.del(url)
              except CatchableError:
                inc failed
                failUrls.add(missing[i][2])
                ctx.faviconFailures[missing[i][2]] = ctx.faviconFailures.getOrDefault(missing[i][2], 0) + 1
            else:
              inc failed
              failUrls.add(missing[i][2])
              ctx.faviconFailures[missing[i][2]] = ctx.faviconFailures.getOrDefault(missing[i][2], 0) + 1
          let failMsg = if failUrls.len > 0: " failed_urls=" & failUrls.join(",") else: ""
          if saved > 0 or failed > 0:
            echo "[favicon] tick=", tick, " tried=", futures.len, " saved=", saved, " failed=", failed, failMsg
      # 2. Re-extract colors for feeds that have a favicon file but no valid color.
      # CAP per tick + yield between extractions: color extraction is
      # synchronous CPU work that runs ON the event loop. Without a cap, the
      # startup pass (clearAllColors nukes every feed) would do 200+ decodes
      # back-to-back and hang the web server for minutes. Doing a bounded
      # batch per 15s tick spreads the work out and keeps the loop live.
      const ColorBatchPerTick = 8
      var colorDone = 0
      for (fid, favPath) in ctx.feedStore.feedsNeedingColor():
        if colorDone >= ColorBatchPerTick: break
        let filePath = "favicons" & favPath[9..^1]   # strip "/favicons/"
        if fileExists(filePath):
          let bytes = readFile(filePath)
          if bytes.len > 0:
            let theme = colorExtractor.extractTheme(bytes)
            if theme.isSome:
              let textColor = colorExtractor.selectTextColor(theme.get)
              ctx.feedStore.setThemeColors(fid, theme.get.bgColor, textColor, textColor)
              ctx.dirty[].store(true)
              inc colorDone
        # Yield to the event loop between CPU-bound extractions so HTTP/WS
        # requests are not starved while the startup backlog is cleared.
        await sleepAsync(0)
      if colorDone > 0:
        echo "[favicon] re-extracted colors for ", colorDone, " feed(s) this tick"

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
