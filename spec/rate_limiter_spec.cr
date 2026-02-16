require "./spec_helper"
require "../src/rate_limiter"

describe Quickheadlines::RateLimiting::RateLimitConfig do
  describe ".limit" do
    it "returns default limit for expensive category" do
      Quickheadlines::RateLimiting::RateLimitConfig.limit("expensive").should eq(5)
    end

    it "returns default limit for moderately category" do
      Quickheadlines::RateLimiting::RateLimitConfig.limit("moderately").should eq(10)
    end

    it "returns default limit for read category" do
      Quickheadlines::RateLimiting::RateLimitConfig.limit("read").should eq(60)
    end

    it "returns default limit for very_expensive category" do
      Quickheadlines::RateLimiting::RateLimitConfig.limit("very_expensive").should eq(3)
    end

    it "returns custom limit when configured" do
      Quickheadlines::RateLimiting::RateLimitConfig.custom_limits = {"test" => 100}
      Quickheadlines::RateLimiting::RateLimitConfig.limit("test").should eq(100)
    end
  end

  describe ".window_size" do
    it "returns 1 hour for expensive category" do
      Quickheadlines::RateLimiting::RateLimitConfig.window_size("expensive").should eq(1.hour)
    end

    it "returns 1 hour for moderately category" do
      Quickheadlines::RateLimiting::RateLimitConfig.window_size("moderately").should eq(1.hour)
    end

    it "returns 1 minute for read category" do
      Quickheadlines::RateLimiting::RateLimitConfig.window_size("read").should eq(1.minute)
    end

    it "returns 1 hour for very_expensive category" do
      Quickheadlines::RateLimiting::RateLimitConfig.window_size("very_expensive").should eq(1.hour)
    end

    it "returns custom window when configured" do
      Quickheadlines::RateLimiting::RateLimitConfig.custom_windows = {"test" => 2.minutes}
      Quickheadlines::RateLimiting::RateLimitConfig.window_size("test").should eq(2.minutes)
    end
  end

  describe ".get_category" do
    it "returns expensive for /api/cluster" do
      Quickheadlines::RateLimiting::RateLimitConfig.get_category("/api/cluster").should eq("expensive")
    end

    it "returns expensive for /api/recluster" do
      Quickheadlines::RateLimiting::RateLimitConfig.get_category("/api/recluster").should eq("expensive")
    end

    it "returns moderately for /api/refresh" do
      Quickheadlines::RateLimiting::RateLimitConfig.get_category("/api/refresh").should eq("moderately")
    end

    it "returns moderately for /api/clear-cache" do
      Quickheadlines::RateLimiting::RateLimitConfig.get_category("/api/clear-cache").should eq("moderately")
    end

    it "returns very_expensive for /api/cleanup-orphaned" do
      Quickheadlines::RateLimiting::RateLimitConfig.get_category("/api/cleanup-orphaned").should eq("very_expensive")
    end

    it "returns read for unknown endpoints" do
      Quickheadlines::RateLimiting::RateLimitConfig.get_category("/api/feeds").should eq("read")
      Quickheadlines::RateLimiting::RateLimitConfig.get_category("/api/items").should eq("read")
    end
  end
end

describe Quickheadlines::RateLimiting::RateLimiter do
  describe "#check_limit" do
    it "allows first request within limit" do
      ip = "unique-test-#{Time.utc.to_unix}"
      result = Quickheadlines::RateLimiting::RateLimiter.new.check_limit(ip, "read")

      result[:allowed].should be_true
      result[:remaining].should eq(59)
      result[:reset_at].should be_a(Int64)
    end

    it "denies request when limit exceeded for expensive category" do
      ip = "unique-exceeded-#{Time.utc.to_unix}"
      limiter = Quickheadlines::RateLimiting::RateLimiter.new

      6.times do
        limiter.check_limit(ip, "expensive")
      end

      result = limiter.check_limit(ip, "expensive")
      result[:allowed].should be_false
      result[:remaining].should eq(0)
    end

    it "tracks requests per IP separately" do
      ip1 = "unique-ip1-#{Time.utc.to_unix}"
      ip2 = "unique-ip2-#{Time.utc.to_unix}"
      limiter = Quickheadlines::RateLimiting::RateLimiter.new

      6.times { limiter.check_limit(ip1, "expensive") }
      result1 = limiter.check_limit(ip1, "expensive")
      result1[:allowed].should be_false

      result2 = limiter.check_limit(ip2, "expensive")
      result2[:remaining].should eq(4)
    end

    it "tracks requests per category separately" do
      ip = "unique-cat-#{Time.utc.to_unix}"
      limiter = Quickheadlines::RateLimiting::RateLimiter.new

      6.times { limiter.check_limit(ip, "expensive") }
      expensive_result = limiter.check_limit(ip, "expensive")
      expensive_result[:allowed].should be_false

      read_result = limiter.check_limit(ip, "read")
      read_result[:remaining].should eq(59)
    end

    it "returns reset_at timestamp" do
      ip = "unique-reset-#{Time.utc.to_unix}"
      result = Quickheadlines::RateLimiting::RateLimiter.new.check_limit(ip, "read")

      result[:reset_at].should be > Time.utc.to_unix
    end
  end

  describe "#should_rate_limit?" do
    it "returns false when under limit" do
      ip = "unique-under-#{Time.utc.to_unix}"
      limiter = Quickheadlines::RateLimiting::RateLimiter.new
      limiter.should_rate_limit?(ip, "expensive").should be_false
    end

    it "returns true when limit exceeded" do
      ip = "unique-limit-#{Time.utc.to_unix}"
      limiter = Quickheadlines::RateLimiting::RateLimiter.new

      6.times { limiter.check_limit(ip, "expensive") }

      limiter.should_rate_limit?(ip, "expensive").should be_true
    end
  end

  describe "#stats" do
    it "returns hash with expected structure" do
      ip = "unique-stats-#{Time.utc.to_unix}"
      limiter = Quickheadlines::RateLimiting::RateLimiter.new

      limiter.check_limit(ip, "expensive")

      stats = limiter.stats

      stats[:total_entries].should be_a(Int32)
      stats[:by_category].should be_a(Hash(String, Int32))
    end
  end
end

describe Quickheadlines::RateLimiting::RateLimitInfo do
  describe "#expired?" do
    it "returns false for fresh info" do
      info = Quickheadlines::RateLimiting::RateLimitInfo.new("read")
      info.expired?(1.minute).should be_false
    end

    it "verifies category is set correctly" do
      info = Quickheadlines::RateLimiting::RateLimitInfo.new("read")
      info.category.should eq("read")
    end
  end
end
