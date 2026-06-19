## In-memory test impls for the service/ops boundaries: Broadcaster,
## ConfigSource, HealthReporter, RateLimiter, ProxyValidator.
##
## These are intentionally simple - enough to satisfy the concepts and let unit
## tests run without sockets, files, or a clock. Production impls (Phase 3)
## wrap real deps behind these same boundaries.

import std/[tables, sets, strutils]
import ../types

# ---------------------------------------------------------------- Broadcaster

type
  InMemoryBroadcaster* = ref object
    subscribers*: int
    sentCount*: int
    closed*: bool

proc broadcast*(b: InMemoryBroadcaster, payload: string): BroadcastResult =
  if b.closed: return errBroadcast(beClosed)
  if b.subscribers == 0: return errBroadcast(beNoSubscribers)
  inc b.sentCount
  okBroadcast(b.subscribers)

# ---------------------------------------------------------------- ConfigSource

type
  InMemoryConfigSource* = ref object
    config*: Config
    fail*: bool

proc load*(c: InMemoryConfigSource): ConfigResult =
  if c.fail: errConfig(ceMalformed)
  else: okConfig(c.config)

# ---------------------------------------------------------------- HealthReporter

type
  InMemoryHealthReporter* = ref object
    healthyFlag*: bool
    detail*: string

proc healthy*(h: InMemoryHealthReporter): bool = h.healthyFlag
proc status*(h: InMemoryHealthReporter): string =
  if h.healthyFlag: "ok: " & h.detail else: "degraded: " & h.detail

# ---------------------------------------------------------------- RateLimiter

type
  InMemoryRateLimiter* = ref object
    budget*: int               ## tokens left per key (reset externally)
    seen*: CountTable[string]

proc check*(r: InMemoryRateLimiter, key: string): RateLimitResult =
  r.seen.inc(key)
  if r.seen[key] > r.budget: denyRate(rlExceeded, remaining = 0)
  else: allowRate(remaining = r.budget - r.seen[key])

# ---------------------------------------------------------------- ProxyValidator

type
  InMemoryProxyValidator* = ref object
    blocked*: HashSet[string]   ## explicitly blocked hosts

proc validate*(v: InMemoryProxyValidator, url: string): ProxyValidateResult =
  ## Trivial stub: production pins the resolved IP and rejects private ranges
  ## (fixes the Crystal P0 DNS-rebinding SSRF, finding context.md #1).
  if url.len == 0: return errProxy(peMalformed)
  for b in v.blocked:
    if url.contains(b): return errProxy(peBlocked)
  okProxy("203.0.113.42")   # deterministic TEST-NET-3 address
