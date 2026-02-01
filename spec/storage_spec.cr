require "spec"
require "../src/storage"
require "../src/config"

describe "Storage" do
  describe "format_bytes" do
    it "formats bytes correctly" do
      format_bytes(0).should eq("0 B")
      format_bytes(1023).should eq("1023 B")
      format_bytes(1024).should eq("1 KB")
      format_bytes(1536).should eq("1.5 KB")
      format_bytes(1024 * 1024).should eq("1 MB")
      format_bytes(50 * 1024 * 1024).should eq("50 MB")
      format_bytes(100 * 1024 * 1024).should eq("100 MB")
      format_bytes(1024 * 1024 * 1024).should eq("1 GB")
    end
  end

  describe "Config" do
    it "has cache_retention_hours property with default value" do
      config = Config.from_yaml("cache_retention_hours: 168")
      config.cache_retention_hours.should eq(168)
    end

    it "uses default value when cache_retention_hours is not specified" do
      config = Config.from_yaml("")
      config.cache_retention_hours.should eq(168)
    end

    it "has max_cache_size_mb property with default value" do
      config = Config.from_yaml("max_cache_size_mb: 100")
      config.max_cache_size_mb.should eq(100)
    end

    it "uses default value when max_cache_size_mb is not specified" do
      config = Config.from_yaml("")
      config.max_cache_size_mb.should eq(100)
    end
  end

  describe "Constants" do
    it "has correct default cache retention" do
      CACHE_RETENTION_HOURS.should eq(168)
    end

    it "has correct database size limits" do
      DB_SIZE_WARNING_THRESHOLD.should eq(50 * 1024 * 1024)
      DB_SIZE_HARD_LIMIT.should eq(100 * 1024 * 1024)
    end

    it "has correct cache retention days" do
      CACHE_RETENTION_DAYS.should eq(7)
    end
  end

  describe "FeedCache#item_count" do
    it "returns zero for non-existent feed URL" do
      cache = FeedCache.new(nil)
      cache.item_count("https://nonexistent.example.com/feed.xml").should eq(0)
    end
  end

  describe "FeedCache#check_size_limit" do
    it "does not raise when database is empty" do
      cache = FeedCache.new(nil)
      cache.check_size_limit(100).should be_nil
    end
  end
end
