## Per-IP sliding-window rate limiter (design D4 boundary). All access is on the
## single async event-loop thread (no lock needed). Capped at 10K IPs to bound
## memory; oldest IPs evicted when full.

import std/[tables, times]

type
  RateLimiter* = ref object
    requests: Table[string, seq[float]]   # IP -> request timestamps (epoch s)
    limit: int
    windowSec: float
    maxEntries: int

proc newRateLimiter*(limit: int = 60; windowSec: float = 60.0;
                     maxEntries: int = 10_000): RateLimiter =
  RateLimiter(limit: limit, windowSec: windowSec, maxEntries: maxEntries)

proc isAllowed*(r: RateLimiter; ip: string): bool =
  ## Check + record a request from `ip`. Returns false if rate-limited.
  let now = epochTime()
  var ts = r.requests.getOrDefault(ip, @[])
  # Slide the window: keep only timestamps within the window.
  var fresh: seq[float] = @[]
  for t in ts:
    if now - t < r.windowSec: fresh.add(t)
  if fresh.len >= r.limit: return false
  fresh.add(now)
  r.requests[ip] = fresh
  # Evict old IPs if table is too large (prevent unbounded memory growth).
  if r.requests.len > r.maxEntries:
    var toRemove: seq[string] = @[]
    for i, t in r.requests:
      var hasRecent = false
      for x in t:
        if now - x < r.windowSec: hasRecent = true; break
      if not hasRecent: toRemove.add(i)
    for ip2 in toRemove: r.requests.del(ip2)
  true

proc remaining*(r: RateLimiter; ip: string): int =
  let now = epochTime()
  let ts = r.requests.getOrDefault(ip, @[])
  var count = 0
  for t in ts:
    if now - t < r.windowSec: inc count
  max(r.limit - count, 0)
