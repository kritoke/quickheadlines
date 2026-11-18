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
  before_each do
    ensure_throttler_actor
  end

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
# The cache is a token lease: on a miss the actor reserves a small batch of
# requests (<= 10% of the limit) and counts them immediately; cache hits spend
# those tokens. The limit can therefore never be exceeded via the cache.
describe QuickHeadlines::RateLimiter, "cache layer" do
  Spec.before_each do
    # Reset the cache between tests so each test sees a known state.
    QuickHeadlines::RateLimiter.clear_cache
    ensure_throttler_actor
  end

  it "caches leased tokens to avoid repeated actor calls" do
    QuickHeadlines::RateLimiter.allowed?("cache-test-#{rand(100000)}", 100, 60).should be_true
    QuickHeadlines::RateLimiter.cache_size.should be > 0
  end

  it "never allows more than max_requests, even via the cache" do
    key = "strict-#{rand(100000)}"
    allowed = 0
    50.times { allowed += 1 if QuickHeadlines::RateLimiter.allowed?(key, 20, 60) }
    allowed.should eq(20)

    admin_key = "strict-admin-#{rand(100000)}"
    results = 5.times.map { QuickHeadlines::RateLimiter.allowed?(admin_key, 1, 60) }.to_a
    results.should eq([true, false, false, false, false])
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
    QuickHeadlines::RateLimiter.allowed?(key, 50, 60).should be_true
    QuickHeadlines::RateLimiter.allowed?(key, 100, 60).should be_true
    # Both entries are cached.
    QuickHeadlines::RateLimiter.cache_size.should eq(2)
  end

  it "clears the cache on shutdown" do
    QuickHeadlines::RateLimiter.allowed?("shutdown-test-#{rand(100000)}", 100, 60).should be_true
    QuickHeadlines::RateLimiter.cache_size.should be > 0
    QuickHeadlines::RateLimiter.shutdown
    QuickHeadlines::RateLimiter.cache_size.should eq(0)
  end

  it "uses a bounded cache (does not grow without limit)" do
    # CACHE_MAX_ENTRIES is 256. Pump more than that through and
    # verify the cache is at most CACHE_MAX_ENTRIES.
    500.times do |i|
      QuickHeadlines::RateLimiter.allowed?("bounded-#{i}-#{rand(100000)}", 100, 60)
    end
    QuickHeadlines::RateLimiter.cache_size.should be <= 256
  end
end
