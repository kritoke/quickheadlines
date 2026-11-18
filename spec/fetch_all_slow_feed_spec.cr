require "./spec_helper"

# Adapter whose fetch takes longer than fetch_all's 10s select wake-up.
class SlowFetcherAdapter
  include FetcherAdapter

  def initialize(@delay : Time::Span)
  end

  def fetch(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
    sleep @delay
    FeedData.new(title: "Slow", url: feed.url, site_link: feed.url, header_color: nil, header_text_color: nil, items: [] of Item)
  end
end

describe "FeedFetcherConcurrent.fetch_all with a slow feed" do
  it "still collects a result that takes longer than one 10s wake-up" do
    previous = FetcherRegistry.impl
    FetcherRegistry.register_impl(SlowFetcherAdapter.new(11.seconds))
    begin
      feed = Feed.from_yaml("title: Slow\nurl: http://slow.test/rss\n")
      config = Config.from_yaml("cache_dir: #{Dir.tempdir}\nitem_limit: 5\ndb_fetch_limit: 50\n")
      result = RefreshLoop::FeedFetcherConcurrent.fetch_all({feed.url => feed}, {} of String => FeedData, config, RefreshLoop::SemaphorePool.new)
      result[feed.url]?.try(&.error_message).should be_nil
      result[feed.url]?.try(&.title).should eq("Slow")
    ensure
      FetcherRegistry.register_impl(previous)
    end
  end
end
