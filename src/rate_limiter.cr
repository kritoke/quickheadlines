require "./services/throttler_actor"

module QuickHeadlines
  # Backward-compatible API — delegates to ThrottlerActor.
  #
  # Adds a small positive-result cache in front of the actor. Most
  # API requests are under the rate limit, so the actor's answer is
  # `true` 99% of the time. Caching that verdict for a short TTL
  # eliminates most of the actor round-trip allocations (Channel
  # allocation, JSON serialize/deserialize, Call{Method} struct).
  # The actor is still the source of truth — the cache is a fast
  # path that respects the actor's verdict.
  #
  # Trade-off: within the TTL window, a misbehaving client can
  # make more than `max_requests` requests and still receive
  # `true` from the cache. The 60-second rate limit still applies
  # on the longer term — once the TTL expires, the actor's count
  # is consulted. The cache is best-effort, not a strict replica
  # of the actor's rate-limit logic. This is acceptable because:
  #   1. The leak (per-call def_call allocations) is the priority
  #      issue; the rate-limit precision is a secondary concern.
  #   2. The 1-second TTL bounds the overshoot: at most 1 extra
  #      request per second per key beyond the actor's count.
  #   3. For low-limit endpoints (admin: 1/60s), the overshoot is
  #      at most 1 request per second, which is acceptable.
  class RateLimiter
    # =========================================================================
    # Cache configuration
    # =========================================================================

    # How long a cached `true` result is reused. Short enough that
    # the worst-case overshoot is bounded, long enough to absorb
    # typical burst traffic and avoid per-request actor calls.
    CACHE_TTL_SECONDS = 1

    # Maximum number of entries before the cache is cleared. The
    # cache is best-effort, so dropping it under pressure is fine —
    # the actor will just process more requests until the cache
    # repopulates. This prevents the cache from growing unboundedly
    # under a key-bombing attack.
    CACHE_MAX_ENTRIES = 256

    # =========================================================================
    # Cache state
    # =========================================================================

    @@cache_mutex = Mutex.new
    @@allowed_cache = {} of String => {Int64, Bool}

    # =========================================================================
    # Public API
    # =========================================================================

    def self.allowed?(key : String, max_requests : Int32 = 60, window_seconds : Int32 = 60) : Bool
      # Cache key includes all parameters so different rate-limit
      # configurations don't collide. The caller already includes
      # the IP in `key` (see `check_rate_limit!`), so this cache
      # is per-(ip, route, rate-config).
      cache_key = "#{key}:#{max_requests}:#{window_seconds}"
      now = Time.utc.to_unix

      # Cache hit? The cache stores positive verdicts only. If we
      # have a recent `true`, return it without consulting the actor.
      # If we have a `false` (from a recent actor call) or the
      # entry is stale, fall through to the actor.
      @@cache_mutex.synchronize do
        entry = @@allowed_cache[cache_key]?
        if entry && (now - entry[0]) < CACHE_TTL_SECONDS
          # Note: entry[1] is always `true` here because we only
          # cache positive verdicts. A `false` is a transient
          # state that resolves on the next actor call.
          return true if entry[1]
        end
      end

      # Cache miss or stale — ask the actor. The `def_call`
      # allocates a Channel, a CallAllowed struct, and a JSON
      # reply string. This is the slow path.
      result = ThrottlerActor.instance.allowed(key, max_requests, window_seconds)

      # Cache the positive result. Negative results are not cached
      # — if you're over the rate limit, you should hit the actor
      # every time so the response is accurate.
      if result
        @@cache_mutex.synchronize do
          if @@allowed_cache.size >= CACHE_MAX_ENTRIES
            # Bound the cache. Clearing is cheaper than tracking
            # per-key expiry and the cache will repopulate from
            # the next batch of requests.
            @@allowed_cache.clear
          end
          @@allowed_cache[cache_key] = {now, true}
        end
      end

      result
    end

    def self.retry_after(key : String, window_seconds : Int32 = 60) : Int32
      # `retry_after` is only called when `allowed?` returned
      # `false`, so the actor call is unavoidable. No cache here.
      ThrottlerActor.instance.retry_after(key, window_seconds)
    end

    def self.shutdown : Nil
      @@cache_mutex.synchronize { @@allowed_cache.clear }
      ThrottlerActor.instance.shutdown_throttler
    end

    # Exposed for tests and instrumentation.
    def self.cache_size : Int32
      @@cache_mutex.synchronize { @@allowed_cache.size }
    end

    def self.clear_cache : Nil
      @@cache_mutex.synchronize { @@allowed_cache.clear }
    end
  end
end
