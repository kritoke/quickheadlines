## Minimal WebSocket helpers (RFC 6455) for the /api/ws push channel.
## Just enough for the server->client 'feed_update' notification: handshake
## accept-key + sending unmasked text frames. (No client-frame parsing beyond
## detecting close; the SPA only sends occasional masked frames we can discard.)

import std/[asyncnet, asyncdispatch, sha1, base64]

const WsGuid* = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

proc wsAcceptKey*(clientKey: string): string =
  ## Sec-WebSocket-Accept = base64(SHA1(clientKey + GUID)).
  base64.encode(Sha1Digest(secureHash(clientKey & WsGuid)))

proc sendWsText*(sock: AsyncSocket; payload: string): Future[void] {.async.} =
  ## Send one unmasked text frame (server -> client).
  var frame = newStringOfCap(payload.len + 10)
  frame.add chr(0x81)                          # FIN + text opcode
  let n = payload.len
  if n <= 125:
    frame.add chr(n)
  elif n <= 0xFFFF:
    frame.add chr(126)
    frame.add char((n shr 8) and 0xFF)
    frame.add char(n and 0xFF)
  else:
    frame.add chr(127)
    for i in 7.countdown(0): frame.add char((n shr (i * 8)) and 0xFF)
  frame.add payload
  await sock.send(frame)
