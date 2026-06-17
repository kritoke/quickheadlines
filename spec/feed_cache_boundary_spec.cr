require "spec"
require "../src/config"
require "../src/models"
require "../src/storage"
require "../src/services/database_service"

# Boundary tests for FeedCache — test the public API, not internal implementation.
# These tests verify that FeedCache works as a black box: inputs in, outputs out.
# If you rewrote the internals, these tests should still pass.

def create_boundary_cache : {FeedCache, DatabaseService}
  config = Config.from_yaml("cache_dir: #{File.join(Dir.tempdir, "qh_boundary_#{Process.pid}_#{Random.rand(10000)}")}")
  db_service = DatabaseService.new(config)
  cache = FeedCache.new(config, db_service)
  {cache, db_service}
end

def boundary_sample_feed(url : String = "https://example.com/feed.xml") : FeedData
  FeedData.new(
    title: "Test Feed",
    url: url,
    site_link: "https://example.com",
    header_color: nil,
    header_text_color: nil,
    items: [
      Item.new("Article 1", "https://example.com/1", Time.utc),
      Item.new("Article 2", "https://example.com/2", Time.utc),
    ],
  )
end

describe "FeedCache boundary" do
  describe "#add and #get" do
    it "stores and retrieves a feed by URL" do
      cache, _ = create_boundary_cache
      feed = boundary_sample_feed

      cache.add(feed)
      result = cache.get("https://example.com/feed.xml")

      result.should_not be_nil
      result.not_nil!.title.should eq("Test Feed")
      result.not_nil!.items.size.should eq(2)
    end

    it "returns nil for unknown URLs" do
      cache, _ = create_boundary_cache

      result = cache.get("https://unknown.com/feed.xml")
      result.should be_nil
    end

    it "overwrites existing feed on same URL" do
      cache, _ = create_boundary_cache
      url = "https://example.com/feed.xml"

      cache.add(boundary_sample_feed(url))
      updated = boundary_sample_feed(url).copy_with(title: "Updated Feed")
      cache.add(updated)

      result = cache.get(url)
      result.not_nil!.title.should eq("Updated Feed")
    end
  end

  describe "#size" do
    it "returns 0 for empty cache" do
      cache, _ = create_boundary_cache
      cache.size.should eq(0)
    end

    it "increments when feeds are added" do
      cache, _ = create_boundary_cache
      cache.add(boundary_sample_feed("https://a.com/feed.xml"))
      cache.add(boundary_sample_feed("https://b.com/feed.xml"))
      cache.size.should eq(2)
    end
  end

  describe "#item_count" do
    it "returns item count for a feed" do
      cache, _ = create_boundary_cache
      cache.add(boundary_sample_feed("https://example.com/feed.xml"))

      cache.item_count("https://example.com/feed.xml").should eq(2)
    end

    it "returns 0 for unknown feed" do
      cache, _ = create_boundary_cache
      cache.item_count("https://unknown.com/feed.xml").should eq(0)
    end
  end

  describe "#item_counts" do
    it "returns counts for multiple URLs" do
      cache, _ = create_boundary_cache
      cache.add(boundary_sample_feed("https://a.com/feed.xml"))
      cache.add(boundary_sample_feed("https://b.com/feed.xml"))

      counts = cache.item_counts(["https://a.com/feed.xml", "https://b.com/feed.xml", "https://c.com/feed.xml"])
      counts["https://a.com/feed.xml"].should eq(2)
      counts["https://b.com/feed.xml"].should eq(2)
      counts["https://c.com/feed.xml"].should eq(0)
    end
  end

  describe "#clear_all" do
    it "removes all feeds" do
      cache, _ = create_boundary_cache
      cache.add(boundary_sample_feed("https://a.com/feed.xml"))
      cache.add(boundary_sample_feed("https://b.com/feed.xml"))

      cache.clear_all
      cache.size.should eq(0)
      cache.get("https://a.com/feed.xml").should be_nil
    end
  end

  describe "#get_fetched_time" do
    it "returns nil for unknown feed" do
      cache, _ = create_boundary_cache
      cache.get_fetched_time("https://unknown.com/feed.xml").should be_nil
    end
  end

  describe "#save and .load" do
    it "persists and reloads cache" do
      config = Config.from_yaml("cache_dir: #{File.join(Dir.tempdir, "qh_boundary_persist_#{Process.pid}_#{Random.rand(10000)}")}")
      db_service = DatabaseService.new(config)
      cache = FeedCache.new(config, db_service)

      cache.add(boundary_sample_feed("https://a.com/feed.xml"))
      cache.add(boundary_sample_feed("https://b.com/feed.xml"))
      cache.save

      # Load fresh instance from same DB
      cache2 = FeedCache.load(config, db_service)
      cache2.size.should eq(2)
      cache2.get("https://a.com/feed.xml").should_not be_nil
    end
  end
end
