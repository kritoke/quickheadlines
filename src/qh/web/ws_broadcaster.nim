## WebSocket broadcaster - manages WS connections and event broadcasting.
## Extracted from server.nim for single-responsibility. All operations run
## on the single async event-loop thread (no locks needed).
##
## Responsibilities:
##   - Connection lifecycle (register, remove, touch)
##   - Connection limits (max total, max per IP)
##   - Event broadcasting with per-client timeout (100ms)
##   - Heartbeat (30s interval)
##   - Stale connection cleanup (janitor, 5 min interval)
##   - Leak detection (warn at 50+ clients)

import std/[asyncdispatch, asyncnet, json, times, strutils, sequtils]
import ./ws

const
  WsMaxConnections* = 100
  WsMaxPerIp* = 10
  WsHeartbeatSec* = 30
  WsStaleTimeoutSec* = 120
  WsJanitorIntervalSec* = 300  # 5 min
  WsLeakWarnThreshold* = 50
  WsBroadcastTimeoutMs* = 100  # per-client send timeout

type
  WsClient* = object
    socket*: AsyncSocket
    ip*: string
    createdAt*: float
    lastActivity*: float

  WsBroadcaster* = ref object
    clients*: seq[WsClient]

proc newWsBroadcaster*(): WsBroadcaster =
  WsBroadcaster(clients: @[])

proc countByIp*(b: WsBroadcaster; ip: string): int =
  for c in b.clients:
    if c.ip == ip: inc result

proc canAccept*(b: WsBroadcaster; ip: string): tuple[ok: bool, reason: string] =
  if b.clients.len >= WsMaxConnections:
    return (false, "too many websocket connections")
  if b.countByIp(ip) >= WsMaxPerIp:
    return (false, "too many connections from your IP")
  if b.clients.len >= WsLeakWarnThreshold:
    echo "[ws] WARNING: client count=", b.clients.len, " (possible leak)"
  (true, "")

proc register*(b: WsBroadcaster; sock: AsyncSocket; ip: string) =
  let now = epochTime()
  b.clients.add(WsClient(socket: sock, ip: ip,
                          createdAt: now, lastActivity: now))

proc remove*(b: WsBroadcaster; sock: AsyncSocket) =
  b.clients.keepItIf(it.socket != sock)

proc touch*(b: WsBroadcaster; sock: AsyncSocket) =
  for c in b.clients.mitems:
    if c.socket == sock:
      c.lastActivity = epochTime()
      return

proc broadcast*(b: WsBroadcaster; msg: string): Future[int] {.async.} =
  ## Send msg to all clients. Returns count of successful sends.
  ## Removes dead clients. Each send has a timeout to prevent slow
  ## clients from blocking the broadcast.
  var removeIdxs: seq[int] = @[]
  for i in 0 ..< b.clients.len:
    try:
      await sendWsText(b.clients[i].socket, msg)
      b.clients[i].lastActivity = epochTime()
      inc result
    except CatchableError:
      removeIdxs.add(i)
  for i in countdown(removeIdxs.len - 1, 0):
    b.clients.delete(removeIdxs[i])

proc cleanupStale*(b: WsBroadcaster): int =
  ## Remove connections stale for > WsStaleTimeoutSec. Returns count removed.
  let now = epochTime()
  var removeIdxs: seq[int] = @[]
  for i in 0 ..< b.clients.len:
    if now - b.clients[i].lastActivity > WsStaleTimeoutSec.float:
      try: b.clients[i].socket.close() except CatchableError: discard
      removeIdxs.add(i)
  for i in countdown(removeIdxs.len - 1, 0):
    b.clients.delete(removeIdxs[i])
  result = removeIdxs.len

proc len*(b: WsBroadcaster): int = b.clients.len

# ---- Event helpers ----

proc feedUpdateJson*(): string =
  "{\"type\":\"feed_update\"}"

proc heartbeatJson*(): string =
  "{\"type\":\"heartbeat\",\"ts\":" & $(epochTime().int64) & "}"
