require "spec"
require "../src/storage"
require "../src/config"
require "./spec_helper"

describe "CleanupRepository" do
  describe "#cleanup_old_entries" do
    it "has method that accepts config_urls parameter with URLs in config" do
      cache = create_test_feed_cache

      cache.cleanup_old_entries(168, ["https://example.com/feed.xml"]).should be_nil
    end

    it "has method that accepts nil config_urls" do
      cache = create_test_feed_cache

      cache.cleanup_old_entries(168, nil).should be_nil
    end

    it "has method that accepts empty config_urls array" do
      cache = create_test_feed_cache

      cache.cleanup_old_entries(168, [] of String).should be_nil
    end
  end
end
