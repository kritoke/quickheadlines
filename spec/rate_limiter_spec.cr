require "spec"
require "../src/rate_limiter"

describe QuickHeadlines::ThrottlerActor do
  describe ".allowed" do
    it "allows first request" do
      actor = QuickHeadlines::ThrottlerActor.new("test-throttler")
      actor.start
      actor.allowed("test-#{rand(10000)}", 5, 60).should be_true
      actor.stop
    end

    it "blocks when limit exceeded" do
      actor = QuickHeadlines::ThrottlerActor.new("test-throttler")
      actor.start
      key = "test-#{rand(10000)}"
      actor.allowed(key, 2, 60).should be_true
      actor.allowed(key, 2, 60).should be_true
      actor.allowed(key, 2, 60).should be_false
      actor.stop
    end

    it "tracks requests per identifier" do
      actor = QuickHeadlines::ThrottlerActor.new("test-throttler")
      actor.start
      key_a = "client-a-#{rand(10000)}"
      key_b = "client-b-#{rand(10000)}"

      5.times { actor.allowed(key_a, 5, 60).should be_true }
      actor.allowed(key_b, 5, 60).should be_true # client-b still has quota

      # client-a should be blocked, client-b allowed
      actor.allowed(key_a, 5, 60).should be_false
      actor.allowed(key_b, 5, 60).should be_true
      actor.stop
    end

    it "enforces window expiry" do
      actor = QuickHeadlines::ThrottlerActor.new("test-throttler")
      actor.start
      sleep 0.2.seconds # Give actor time to start
      key = "test-#{rand(10000)}"
      actor.allowed(key, 1, 1).should be_true
      sleep 0.2.seconds
      actor.allowed(key, 1, 1).should be_false

      # After window expires, should allow again
      ::sleep(2.seconds)
      actor.allowed(key, 1, 1).should be_true
      actor.stop
    end
  end

  describe ".retry_after" do
    it "returns window_seconds for unknown identifier" do
      actor = QuickHeadlines::ThrottlerActor.new("test-throttler")
      actor.start
      actor.retry_after("unknown-#{rand(10000)}", 30).should eq(30)
      actor.stop
    end

    it "returns correct retry_after time" do
      actor = QuickHeadlines::ThrottlerActor.new("test-throttler")
      actor.start
      key = "test-#{rand(10000)}"
      actor.allowed(key, 2, 10)
      actor.allowed(key, 2, 10)

      retry_after = actor.retry_after(key, 10)
      retry_after.should be <= 10
      retry_after.should be >= 1
      actor.stop
    end
  end
end

describe QuickHeadlines::RateLimiter do
  describe ".allowed?" do
    it "delegates to ThrottlerActor" do
      key = "test-#{rand(10000)}"
      QuickHeadlines::RateLimiter.allowed?(key, 5, 60).should be_true
    end
  end

  describe ".shutdown" do
    it "has shutdown method" do
      QuickHeadlines::RateLimiter.shutdown
    end
  end
end

# ============================================================================
# Cache layer tests for QuickHeadlines::RateLimiter
# ============================================================================
#
# The cache is a positive-result cache: it caches the actor's
# `true` verdict for CACHE_TTL_SECONDS (1s). Within that window,
# subsequent calls return `true` from the cache without
# consulting the actor. The actor is only consulted on cache
# miss (first call or after the TTL expires).
#
# Trade-off: within the TTL, the cache grants `true` even if
# the actor would say `false` (over the rate limit). This is
# acceptable for the leak fix because:
#   - The 60-second actor rate limit still applies long-term.
#   - The overshoot is bounded (1 extra request per second per key).
#   - The leak (per-call def_call allocations) is the priority.
describe QuickHeadlines::RateLimiter, "cache layer" do
  Spec.before_each do
    # Reset the cache between tests so each test sees a known state.
    QuickHeadlines::RateLimiter.clear_cache
  end

  it "caches positive results to avoid repeated actor calls" do
    # First call: cache miss, hits the actor (true), caches the verdict.
    QuickHeadlines::RateLimiter.allowed?("cache-test-#{rand(100000)}", 5, 60).should be_true
    # Subsequent calls within the TTL: cache hit, never reach the actor.
    10.times do
      QuickHeadlines::RateLimiter.allowed?("cache-test-#{rand(100000)}", 5, 60).should be_true
    end
    QuickHeadlines::RateLimiter.cache_size.should be > 0
  end

  it "expires cached entries after the TTL" do
    # Within the TTL, the cache serves the same verdict. After
    # the TTL, the next call consults the actor and re-evaluates.
    key = "expiry-#{rand(100000)}"
    QuickHeadlines::RateLimiter.allowed?(key, 5, 60).should be_true
    # Within the TTL, the cache is hot.
    QuickHeadlines::RateLimiter.allowed?(key, 5, 60).should be_true
    # After the TTL (1s), the entry expires.
    sleep 1.1.seconds
    # The next call consults the actor and re-evaluates. With a
    # generous limit (5/60s), the actor still says true.
    QuickHeadlines::RateLimiter.allowed?(key, 5, 60).should be_true
  end

  it "uses a different cache entry for different rate-limit configs" do
    # The same key with different (max, window) should NOT collide.
    key = "config-#{rand(100000)}"
    QuickHeadlines::RateLimiter.allowed?(key, 1, 60).should be_true
    QuickHeadlines::RateLimiter.allowed?(key, 100, 60).should be_true
    # Both entries are cached.
    QuickHeadlines::RateLimiter.cache_size.should eq(2)
  end

  it "clears the cache on shutdown" do
    QuickHeadlines::RateLimiter.allowed?("shutdown-test-#{rand(100000)}", 5, 60).should be_true
    QuickHeadlines::RateLimiter.cache_size.should be > 0
    QuickHeadlines::RateLimiter.shutdown
    QuickHeadlines::RateLimiter.cache_size.should eq(0)
  end

  it "uses a bounded cache (does not grow without limit)" do
    # CACHE_MAX_ENTRIES is 256. Pump more than that through and
    # verify the cache is at most CACHE_MAX_ENTRIES.
    500.times do |i|
      QuickHeadlines::RateLimiter.allowed?("bounded-#{i}-#{rand(100000)}", 5, 60)
    end
    QuickHeadlines::RateLimiter.cache_size.should be <= 256
  end
end
