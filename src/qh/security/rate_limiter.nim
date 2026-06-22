## Per-IP per-endpoint sliding-window rate limiter (design D4 boundary).
## All access is on the single async event-loop thread (no lock needed).
## Capped at 10K IPs to bound memory; oldest IPs evicted when full.
## Supports per-endpoint limits by composing key as "endpoint:ip".

import std/[tables, times]

type
  RateLimiter* = ref object
    requests: Table[string, seq[float]]   # key -> request timestamps (epoch s)
    defaultLimit: int
    windowSec: float
    maxEntries: int

proc newRateLimiter*(limit: int = 60; windowSec: float = 60.0;
                     maxEntries: int = 10_000): RateLimiter =
  RateLimiter(defaultLimit: limit, windowSec: windowSec, maxEntries: maxEntries)

proc isAllowed*(r: RateLimiter; key: string; limit: int = 0): bool =
  ## Check + record a request for `key`. Returns false if rate-limited.
  ## If limit > 0, uses per-key limit; otherwise uses defaultLimit.
  let effectiveLimit = if limit > 0: limit else: r.defaultLimit
  let now = epochTime()
  var ts = r.requests.getOrDefault(key, @[])
  # Slide the window: keep only timestamps within the window.
  var fresh: seq[float] = @[]
  for t in ts:
    if now - t < r.windowSec: fresh.add(t)
  if fresh.len >= effectiveLimit: return false
  fresh.add(now)
  r.requests[key] = fresh
  # Evict old keys if table is too large (prevent unbounded memory growth).
  if r.requests.len > r.maxEntries:
    var toRemove: seq[string] = @[]
    for k, t in r.requests:
      var hasRecent = false
      for x in t:
        if now - x < r.windowSec: hasRecent = true; break
      if not hasRecent: toRemove.add(k)
    for k in toRemove: r.requests.del(k)
  true

proc retryAfter*(r: RateLimiter; key: string; limit: int = 0): int =
  ## Returns seconds until the oldest request in the window expires.
  ## Returns 0 if not rate-limited.
  let effectiveLimit = if limit > 0: limit else: r.defaultLimit
  let now = epochTime()
  let ts = r.requests.getOrDefault(key, @[])
  var fresh: seq[float] = @[]
  for t in ts:
    if now - t < r.windowSec: fresh.add(t)
  if fresh.len < effectiveLimit: return 0
  # Oldest request expires in (windowSec - elapsed) seconds.
  let oldest = fresh[0]
  max(1, int(r.windowSec - (now - oldest)) + 1)

proc remaining*(r: RateLimiter; key: string; limit: int = 0): int =
  let effectiveLimit = if limit > 0: limit else: r.defaultLimit
  let now = epochTime()
  let ts = r.requests.getOrDefault(key, @[])
  var count = 0
  for t in ts:
    if now - t < r.windowSec: inc count
  max(effectiveLimit - count, 0)
