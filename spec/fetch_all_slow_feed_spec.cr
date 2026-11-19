require "./spec_helper"

describe "FeedFetcherConcurrent.fetch_all with a slow feed" do
  it "still collects a result that takes longer than one 10s wake-up" do
    # Fetch takes longer than fetch_all's 10s select wake-up.
    FeedFetcher.fetch_override = ->(feed : Feed, _limit : Int32, _db_limit : Int32, _prev : FeedData?) do
      sleep 11.seconds
      FeedData.new(title: "Slow", url: feed.url, site_link: feed.url, header_color: nil, header_text_color: nil, items: [] of Item)
    end
    begin
      feed = Feed.from_yaml("title: Slow\nurl: http://slow.test/rss\n")
      config = Config.from_yaml("cache_dir: #{Dir.tempdir}\nitem_limit: 5\ndb_fetch_limit: 50\n")
      result = RefreshLoop::FeedFetcherConcurrent.fetch_all({feed.url => feed}, {} of String => FeedData, config, RefreshLoop::SemaphorePool.new)
      result[feed.url]?.try(&.error_message).should be_nil
      result[feed.url]?.try(&.title).should eq("Slow")
    ensure
      FeedFetcher.fetch_override = nil
    end
  end
end
