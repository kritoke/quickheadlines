record Item, title : String, link : String, pub_date : Time?, version : String? = nil
record FirehoseItem, item : Item, feed_title : String, feed_url : String, feed_link : String, favicon : String?, favicon_data : String?, header_color : String?
record FeedData, title : String, url : String, site_link : String, header_color : String?, items : Array(Item), etag : String? = nil, last_modified : String? = nil, favicon : String? = nil, favicon_data : String? = nil do
  def display_header_color
    (header_color.try(&.strip).presence) || "transparent"
  end

  def display_link
    site_link.empty? ? url : site_link
  end
end

class Tab
  property name : String
  property feeds = [] of FeedData
  property software_releases = [] of FeedData

  def initialize(@name)
  end
end

class AppState
  property feeds = [] of FeedData
  property software_releases = [] of FeedData
  property tabs = [] of Tab
  property updated_at = Time.local
  property config_title = "Quick Headlines"
  property config : Config?

  # Firehose cache with TTL
  @firehose_cache = {items: [] of FirehoseItem, cached_at: Time.local}
  FIREHOSE_CACHE_TTL = 30.seconds

  def feeds_for_tab(tab_name : String)
    tabs.find { |tab| tab.name == tab_name }.try(&.feeds) || [] of FeedData
  end

  def releases_for_tab(tab_name : String)
    tabs.find { |tab| tab.name == tab_name }.try(&.software_releases) || [] of FeedData
  end

  # Get all items from all feeds for firehose view, sorted by publication date (newest first)
  def all_firehose_items : Array(FirehoseItem)
    # Check cache first
    if (Time.local - @firehose_cache[:cached_at]) < FIREHOSE_CACHE_TTL
      return @firehose_cache[:items]
    end

    items = [] of FirehoseItem

    # Add items from top-level feeds
    feeds.each do |feed|
      feed.items.each do |item|
        items << FirehoseItem.new(
          item,
          feed.title,
          feed.url,
          feed.site_link,
          feed.favicon,
          feed.favicon_data,
          feed.header_color
        )
      end
    end

    # Add items from all tab feeds
    tabs.each do |tab|
      tab.feeds.each do |feed|
        feed.items.each do |item|
          items << FirehoseItem.new(
            item,
            feed.title,
            feed.url,
            feed.site_link,
            feed.favicon,
            feed.favicon_data,
            feed.header_color
          )
        end
      end
    end

    # Sort by publication date (newest first), items without dates go to the end
    items.sort_by do |firehose_item|
      firehose_item.item.pub_date || Time.utc(1970, 1, 1)
    end.reverse!

    # Update cache
    @firehose_cache = {items: items, cached_at: Time.local}
    items
  end

  def update(updated_at : Time)
    @updated_at = updated_at
    # Invalidate firehose cache when feeds are updated
    @firehose_cache = {items: @firehose_cache[:items], cached_at: Time.local - FIREHOSE_CACHE_TTL}
  end
end

STATE = AppState.new

# Global feed cache (singleton accessor)
class FeedCache
  @@instance : FeedCache?

  def self.instance : FeedCache
    @@instance ||= FeedCache.new(nil)
  end

  def self.instance=(cache : FeedCache)
    @@instance = cache
  end
end

FEED_CACHE = FeedCache.instance
