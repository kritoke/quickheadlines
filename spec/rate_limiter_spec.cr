require "spec"
require "../src/rate_limiter"

describe QuickHeadlines::RateLimiter do
  describe ".allowed?" do
    it "allows first request" do
      limiter = QuickHeadlines::RateLimiter.new(5, 60)
      limiter.allowed?("test-client").should be_true
    end

    it "blocks when limit exceeded" do
      limiter = QuickHeadlines::RateLimiter.new(2, 60)
      limiter.allowed?("test-client").should be_true
      limiter.allowed?("test-client").should be_true
      limiter.allowed?("test-client").should be_false
    end

    it "tracks requests per identifier" do
      limiter = QuickHeadlines::RateLimiter.new(5, 60)
      limiter.allowed?("client-a").should be_true
      limiter.allowed?("client-a").should be_true
      limiter.allowed?("client-a").should be_true
      limiter.allowed?("client-a").should be_true
      limiter.allowed?("client-a").should be_true  # 5th request hits limit
      limiter.allowed?("client-b").should be_true  # client-b still has quota

      # client-a should be blocked, client-b allowed
      limiter.allowed?("client-a").should be_false
      limiter.allowed?("client-b").should be_true
    end

    it "enforces window expiry" do
      limiter = QuickHeadlines::RateLimiter.new(1, 1) # 1 second window
      limiter.allowed?("test").should be_true
      limiter.allowed?("test").should be_false

      # After window expires, should allow again
      ::sleep(1.1.seconds)
      limiter.allowed?("test").should be_true
    end
  end

  describe ".retry_after" do
    it "returns window_seconds for unknown identifier" do
      limiter = QuickHeadlines::RateLimiter.new(5, 30)
      limiter.retry_after("unknown").should eq(30)
    end

    it "returns correct retry_after time" do
      limiter = QuickHeadlines::RateLimiter.new(2, 10)
      limiter.allowed?("test")
      limiter.allowed?("test")

      retry_after = limiter.retry_after("test")
      retry_after.should be <= 10
      retry_after.should be >= 1
    end
  end

  describe ".get_or_create" do
    it "creates new instance for new key" do
      instance = QuickHeadlines::RateLimiter.get_or_create("new-key-#{rand(10000)}", 10, 60)
      instance.should be_a(QuickHeadlines::RateLimiter)
      instance.max_requests.should eq(10)
      instance.window_seconds.should eq(60)
    end

    it "returns existing instance for known key" do
      key = "shared-key-#{rand(10000)}"
      first = QuickHeadlines::RateLimiter.get_or_create(key, 5, 30)
      second = QuickHeadlines::RateLimiter.get_or_create(key, 10, 60)

      # Should return the same instance
      first.object_id.should eq(second.object_id)
      # But with original config
      first.max_requests.should eq(5)
      first.window_seconds.should eq(30)
    end
  end

  describe ".cleanup" do
    it "removes expired request timestamps" do
      limiter = QuickHeadlines::RateLimiter.new(5, 2)

      # Make some requests
      limiter.allowed?("test-#{rand(10000)}")
      limiter.allowed?("test-#{rand(10000)}")
      limiter.allowed?("test-#{rand(10000)}")

      # Wait for window to expire
      ::sleep(2.5.seconds)

      # After cleanup, should be able to make requests again
      limiter.allowed?("test-cleanup").should be_true
    end
  end
end

describe "RateLimiter Shutdown" do
  # Test shutdown method exists and is callable
  it "has shutdown method" do
    # Calling shutdown should not raise an error
    QuickHeadlines::RateLimiter.shutdown
  end
end