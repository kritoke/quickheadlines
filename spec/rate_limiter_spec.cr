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
      sleep 0.05.seconds # Give actor time to start
      key = "test-#{rand(10000)}"
      actor.allowed(key, 1, 1).should be_true
      sleep 0.05.seconds # Give actor time to process
      actor.allowed(key, 1, 1).should be_false

      # After window expires, should allow again
      ::sleep(1.1.seconds)
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
