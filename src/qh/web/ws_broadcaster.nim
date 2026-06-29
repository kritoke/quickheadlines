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

import std/[asyncdispatch, asyncnet, times, strutils, sequtils]
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

proc sendWithTimeout(sock: AsyncSocket; msg: string;
                    timeoutMs: int): Future[bool] {.async.} =
  ## Race a WS send against a hard deadline. Returns true on success, false on
  ## timeout/failure. The broadcast runs on the server's single event loop, so a
  ## single slow/half-dead client whose write buffer is full would otherwise
  ## block the ENTIRE loop — freezing out new WS handshakes and HTTP requests
  ## (the 'websocket connect issues' symptom). Abandoning the send after
  ## timeoutMs keeps the loop live; the dead client is removed by the caller.
  let sendFut = sendWsText(sock, msg)
  let timer = sleepAsync(timeoutMs)
  await sendFut or timer
  if sendFut.finished and not sendFut.failed:
    return true
  # Timed out or failed. Best-effort close to release the FD; the caller drops
  # it from the client list. Don't await — we're already past the deadline.
  if not sendFut.finished:
    try: sock.close() except CatchableError: discard
  return false

proc broadcast*(b: WsBroadcaster; msg: string): Future[int] {.async.} =
  ## Send msg to all clients. Returns count of successful sends.
  ## Removes dead/timed-out clients. Each send is capped at WsBroadcastTimeoutMs
  ## so a single slow client cannot stall the server's event loop.
  if b.clients.len == 0: return
  # Snapshot the client list: a slow client must not block sends to later
  # clients, and we must not mutate b.clients while iterating it.
  let snapshot = b.clients
  var dead: seq[AsyncSocket] = @[]
  for c in snapshot:
    let ok = await sendWithTimeout(c.socket, msg, WsBroadcastTimeoutMs)
    if ok:
      b.touch(c.socket)
      inc result
    else:
      dead.add(c.socket)
  for sock in dead:
    b.remove(sock)
  if dead.len > 0:
    echo "[ws] broadcast: dropped ", dead.len, " unresponsive client(s) (remaining=", b.clients.len, ")"

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
