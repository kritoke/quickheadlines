require "./services/throttler_actor"

module QuickHeadlines
  # Backward-compatible API — delegates to ThrottlerActor.
  #
  # Adds a small token-lease cache in front of the actor to avoid an actor
  # round-trip per request. On a miss, the actor *reserves* a small batch of
  # requests (at most 10% of the limit, capped at LEASE_MAX) and records them
  # as used; cache hits then spend those pre-counted tokens. The actor's count
  # therefore never under-counts, so the limit can't be exceeded. The cost is
  # that unused leased tokens still count against the client for the window.
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
    @@allowed_cache = {} of String => {Int64, Int32}

    # =========================================================================
    # Public API
    # =========================================================================

    LEASE_MAX = 10

    def self.allowed?(key : String, max_requests : Int32 = 60, window_seconds : Int32 = 60) : Bool
      cache_key = "#{key}:#{max_requests}:#{window_seconds}"
      now = Time.utc.to_unix

      @@cache_mutex.synchronize do
        if entry = @@allowed_cache[cache_key]?
          ts, tokens = entry
          if (now - ts) < CACHE_TTL_SECONDS && tokens > 0
            @@allowed_cache[cache_key] = {ts, tokens - 1}
            return true
          end
          @@allowed_cache.delete(cache_key)
        end
      end

      want = (max_requests // 10).clamp(1, LEASE_MAX)
      granted = ThrottlerActor.instance.reserve(key, max_requests, window_seconds, want)
      return false if granted <= 0

      # One token is spent by this request; cache the rest.
      if granted > 1
        @@cache_mutex.synchronize do
          @@allowed_cache.clear if @@allowed_cache.size >= CACHE_MAX_ENTRIES
          @@allowed_cache[cache_key] = {now, granted - 1}
        end
      end
      true
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
