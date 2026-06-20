## Per-IP sliding-window rate limiter (design D4 boundary). All access is on the
## single async event-loop thread (no lock needed). Capped at 10K IPs to bound
## memory; oldest half evicted when full.

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

proc evictOld(r: RateLimiter) =
  if r.requests.len <= r.maxEntries: return
  let now = epochTime()
  var dead: seq[string] = @[]
  for ip, ts in r.requests:
    # If all timestamps are outside the window, the IP is inactive.
    var hasRecent = false
    for t in ts:
      if now - t < r.windowSec: hasRecent = true; break
    if not hasRecent: dead.add(ip)
  for ip in dead: r.requests.del(ip)
  # If still over cap, evict the oldest half (by last-request time).
  if r.requests.len > r.maxEntries:
    let pairs = toSeq(r.requests.pairs)
    pairs.sort do (a, b: auto) -> int: cmp(
      a[1][^1], b[1][^1])           # oldest last-request first
    for i in 0 ..< pairs.len div 2:
      r.requests.del(pairs[i][0])

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
  r.evictOld()
  true

proc remaining*(r: RateLimiter; ip: string): int =
  ## Tokens remaining for `ip` (for Retry-After header info).
  let now = epochTime()
  let ts = r.requests.getOrDefault(ip, @[])
  var count = 0
  for t in ts:
    if now - t < r.windowSec: inc count
  max(r.limit - count, 0)
