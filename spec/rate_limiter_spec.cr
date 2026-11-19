require "spec"
require "../src/rate_limiter"

describe QuickHeadlines::RateLimiter do
  before_each { QuickHeadlines::RateLimiter.clear_cache }

  it "allows the first request" do
    QuickHeadlines::RateLimiter.allowed?("first-#{rand(100000)}", 5, 60).should be_true
  end

  it "never allows more than max_requests in a window" do
    key = "strict-#{rand(100000)}"
    allowed = 0
    50.times { allowed += 1 if QuickHeadlines::RateLimiter.allowed?(key, 20, 60) }
    allowed.should eq(20)

    single = "single-#{rand(100000)}"
    Array.new(5) { QuickHeadlines::RateLimiter.allowed?(single, 1, 60) }
      .should eq([true, false, false, false, false])
  end

  it "tracks keys independently" do
    a = "client-a-#{rand(100000)}"
    b = "client-b-#{rand(100000)}"
    5.times { QuickHeadlines::RateLimiter.allowed?(a, 5, 60).should be_true }
    QuickHeadlines::RateLimiter.allowed?(a, 5, 60).should be_false
    QuickHeadlines::RateLimiter.allowed?(b, 5, 60).should be_true
  end

  it "keeps separate windows for different limit configs" do
    key = "config-#{rand(100000)}"
    QuickHeadlines::RateLimiter.allowed?(key, 1, 60).should be_true
    QuickHeadlines::RateLimiter.allowed?(key, 1, 60).should be_false
    QuickHeadlines::RateLimiter.allowed?(key, 2, 60).should be_true
    QuickHeadlines::RateLimiter.cache_size.should eq(2)
  end

  it "allows again after the window expires" do
    key = "expiry-#{rand(100000)}"
    QuickHeadlines::RateLimiter.allowed?(key, 1, 1).should be_true
    QuickHeadlines::RateLimiter.allowed?(key, 1, 1).should be_false
    sleep 2.1.seconds
    QuickHeadlines::RateLimiter.allowed?(key, 1, 1).should be_true
  end

  it "is exact under concurrent callers" do
    key = "concurrent-#{rand(100000)}"
    done = Channel(Bool).new
    100.times { spawn { done.send QuickHeadlines::RateLimiter.allowed?(key, 30, 60) } }
    Array.new(100) { done.receive }.count(true).should eq(30)
  end

  describe ".retry_after" do
    it "returns window_seconds for an unknown key" do
      QuickHeadlines::RateLimiter.retry_after("unknown-#{rand(100000)}", 30).should eq(30)
    end

    it "returns a value within the window for a limited key" do
      key = "retry-#{rand(100000)}"
      2.times { QuickHeadlines::RateLimiter.allowed?(key, 2, 10) }
      (1..10).should contain(QuickHeadlines::RateLimiter.retry_after(key, 10))
    end
  end

  it "clears all windows on shutdown" do
    QuickHeadlines::RateLimiter.allowed?("shutdown-#{rand(100000)}", 5, 60)
    QuickHeadlines::RateLimiter.cache_size.should be > 0
    QuickHeadlines::RateLimiter.shutdown
    QuickHeadlines::RateLimiter.cache_size.should eq(0)
  end
end
