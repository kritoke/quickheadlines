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

type
  ServerCtx* = ref object
    config*: Config
    feedStore*: SqliteFeedStore
    itemStore*: SqliteItemStore
    contentStore*: SqliteContentStore
    startedAtMs*: int64
    dirty*: ref Atomic[bool]     # set by refresh supervisor -> watcher broadcasts
    rateLimiter*: RateLimiter
    proxyValidator*: ProxyValidator

# ---- WebSocket connection management ----
const
  WsMaxConnections* = 100
  WsMaxPerIp* = 10
  WsHeartbeatSec* = 30
  WsStaleTimeoutSec* = 120
  WsJanitorIntervalSec* = 300  # 5 min
  WsLeakWarnThreshold* = 50

type
  WsClient = object
    socket: AsyncSocket
    ip: string
    createdAt: float       # epoch seconds
    lastActivity: float    # epoch seconds

var wsClients: seq[WsClient] = @[]

# Favicon failure tracking — skip feeds that fail repeatedly.
var faviconFailures: Table[string, int]

proc wsCountByIp(ip: string): int =
  for c in wsClients:
    if c.ip == ip: inc result

proc wsRemoveClient(sock: AsyncSocket) =
  wsClients.keepItIf(it.socket != sock)

proc wsTouch(sock: AsyncSocket) =
  for c in wsClients.mitems:
    if c.socket == sock:
      c.lastActivity = epochTime()
      return

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
proc wsSession(req: Request): Future[void] {.async.} =
  let key = req.headers.getOrDefault("Sec-WebSocket-Key")
  if key.len == 0:
    await req.respond(Http400, $(%*{"error": "missing Sec-WebSocket-Key"}), jsonHeaders())
    return
  # Connection limits.
  let (peerIp, _) = req.client.getPeerAddr()
  if wsClients.len >= WsMaxConnections:
    await req.respond(Http429, $(%*{"error": "too many websocket connections"}), jsonHeaders())
    return
  if wsCountByIp(peerIp) >= WsMaxPerIp:
    await req.respond(Http429, $(%*{"error": "too many connections from your IP"}), jsonHeaders())
    return
  # Leak detection.
  if wsClients.len >= WsLeakWarnThreshold:
    echo "[ws] WARNING: client count=", wsClients.len, " (possible leak)"
  let accept = wsAcceptKey(key)
  await req.client.send(
    "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n" &
    "Connection: Upgrade\r\nSec-WebSocket-Accept: " & accept & "\r\n\r\n")
  let now = epochTime()
  wsClients.add(WsClient(socket: req.client, ip: peerIp,
                          createdAt: now, lastActivity: now))
  try:
    while true:
      let data = await req.client.recv(4096)       # detect close; discard frames
      if data.len == 0: break
      wsTouch(req.client)                          # update activity
  except CatchableError:
    discard
  wsRemoveClient(req.client)

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
    await req.wsSession()
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
    await req.respond(Http200, $statusJson(false, 0), jsonHeaders())

  of "/api/health":
    await req.respond(Http200, $(%*{"status": "ok"}), jsonHeaders())

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

proc feedWatcher(ctx: ServerCtx): Future[void] {.async.} =
  ## Periodically push a WS 'feed_update' when feeds change, AND progressively
  ## fetch missing favicons (async, in the event loop - can't deadlock the feed
  ## worker pool the way a threaded sync fetcher did).
  var tick = 0
  while true:
    await sleepAsync(1000)
    inc tick

    # ---- WS broadcast on dirty flag ----
    if wsClients.len > 0 and ctx.dirty[].load():
      ctx.dirty[].store(false)
      var removeIdxs: seq[int] = @[]
      for i in 0 ..< wsClients.len:
        try: await sendWsText(wsClients[i].socket, "{\"type\":\"feed_update\"}")
        except CatchableError: removeIdxs.add(i); continue
        wsClients[i].lastActivity = epochTime()
      for i in removeIdxs.reversed: wsClients.delete(i)

    # ---- WS heartbeat every 30s ----
    if wsClients.len > 0 and tick mod WsHeartbeatSec == 0:
      let hb = "{\"type\":\"heartbeat\",\"ts\":" & $(epochTime().int64) & "}"
      var removeIdxs: seq[int] = @[]
      for i in 0 ..< wsClients.len:
        try: await sendWsText(wsClients[i].socket, hb)
        except CatchableError: removeIdxs.add(i); continue
        wsClients[i].lastActivity = epochTime()
      for i in removeIdxs.reversed: wsClients.delete(i)

    # ---- WS janitor every 5 min: clean stale connections ----
    if tick mod WsJanitorIntervalSec == 0 and wsClients.len > 0:
      let now = epochTime()
      var removeIdxs: seq[int] = @[]
      for i in 0 ..< wsClients.len:
        if now - wsClients[i].lastActivity > WsStaleTimeoutSec.float:
          try: wsClients[i].socket.close() except CatchableError: discard
          removeIdxs.add(i)
      for i in removeIdxs.reversed: wsClients.delete(i)
      if removeIdxs.len > 0:
        echo "[ws] janitor: removed ", removeIdxs.len, " stale connections (remaining=", wsClients.len, ")"

    # ---- Favicon: fetch several missing icons concurrently every 3s ----
    if tick mod 3 == 0:
      # 1. Fetch missing favicons.
      let missing = ctx.feedStore.feedsMissingFavicon(8)
      if missing.len > 0:
        var futures: seq[Future[Option[FavBytes]]] = @[]
        for (id, siteLink, url) in missing:
          # Skip feeds that have failed recently (in-memory backoff).
          let failKey = url
          if failKey in faviconFailures and faviconFailures[failKey] >= 3:
            continue
          futures.add fetchFaviconAsync(siteLink, url)
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
                faviconFailures.del(url)
              except CatchableError:
                inc failed
                failUrls.add(missing[i][2])
                faviconFailures[missing[i][2]] = faviconFailures.getOrDefault(missing[i][2], 0) + 1
            else:
              inc failed
              failUrls.add(missing[i][2])
              faviconFailures[missing[i][2]] = faviconFailures.getOrDefault(missing[i][2], 0) + 1
          let failMsg = if failUrls.len > 0: " failed_urls=" & failUrls.join(",") else: ""
          if saved > 0 or failed > 0:
            echo "[favicon] tick=", tick, " tried=", futures.len, " saved=", saved, " failed=", failed, failMsg
      # 2. Re-extract colors for feeds that have a favicon file but no valid color.
      for (fid, favPath) in ctx.feedStore.feedsNeedingColor():
        let filePath = "favicons" & favPath[9..^1]   # strip "/favicons/"
        if fileExists(filePath):
          let bytes = readFile(filePath)
          if bytes.len > 0:
            let theme = colorExtractor.extractTheme(bytes)
            if theme.isSome:
              let textColor = colorExtractor.selectTextColor(theme.get)
              ctx.feedStore.setThemeColors(fid, theme.get.bgColor, textColor, textColor)
              ctx.dirty[].store(true)

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
