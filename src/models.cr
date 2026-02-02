record Item, title : String, link : String, pub_date : Time?, version : String? = nil
record TimelineItem, item : Item, feed_title : String, feed_url : String, feed_link : String, favicon : String?, favicon_data : String?, header_color : String?, header_text_color : String?

# Extended TimelineItem with cluster information for story grouping
record ClusteredTimelineItem,
  item : Item,
  feed_title : String,
  feed_url : String,
  feed_link : String,
  favicon : String?,
  favicon_data : String?,
  header_color : String?,
  header_text_color : String?,
  cluster_id : Int64?,
  is_representative : Bool,
  cluster_size : Int32?

# Helper to create ClusteredTimelineItem from TimelineItem
def to_clustered(item : TimelineItem, cluster_id : Int64?, is_representative : Bool, cluster_size : Int32?) : ClusteredTimelineItem
  ClusteredTimelineItem.new(
    item.item,
    item.feed_title,
    item.feed_url,
    item.feed_link,
    item.favicon,
    item.favicon_data,
    item.header_color,
    item.header_text_color,
    cluster_id,
    is_representative,
    cluster_size
  )
end

# Story grouping result
record StoryGroup,
  representative : ClusteredTimelineItem,
  others : Array(ClusteredTimelineItem)

record FeedData, title : String, url : String, site_link : String, header_color : String?, header_text_color : String?, items : Array(Item), etag : String? = nil, last_modified : String? = nil, favicon : String? = nil, favicon_data : String? = nil do
  def display_header_color
    (header_color.try(&.strip).presence) || "transparent"
  end

  def display_header_text_color
    header_text_color.try(&.strip).presence
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
  property is_clustering : Bool = false

  # Timeline cache with TTL
  @timeline_cache = {items: [] of TimelineItem, cached_at: Time.local}
  TIMELINE_CACHE_TTL = 30.seconds

  def feeds_for_tab(tab_name : String)
    tabs.find { |tab| tab.name.downcase == tab_name.downcase }.try(&.feeds) || [] of FeedData
  end

  def releases_for_tab(tab_name : String)
    tabs.find { |tab| tab.name.downcase == tab_name.downcase }.try(&.software_releases) || [] of FeedData
  end

  # Get all items from all feeds for timeline view, sorted by publication date (newest first)
  def all_timeline_items : Array(TimelineItem)
    items = [] of TimelineItem

    # Add items from top-level feeds
    feeds.each do |feed|
      feed.items.each do |item|
        items << TimelineItem.new(
          item,
          feed.title,
          feed.url,
          feed.site_link,
          feed.favicon,
          feed.favicon_data,
          feed.header_color,
          feed.header_text_color
        )
      end
    end

    # Add items from all tab feeds
    tabs.each do |tab|
      tab.feeds.each do |feed|
        feed.items.each do |item|
          items << TimelineItem.new(
            item,
            feed.title,
            feed.url,
            feed.site_link,
            feed.favicon,
            feed.favicon_data,
            feed.header_color,
            feed.header_text_color
          )
        end
      end
    end

    # Sort by publication date (newest first), items without dates go to end
    items.sort! do |a, b|
      date_a = a.item.pub_date
      date_b = b.item.pub_date
      if date_a && date_b
        date_b <=> date_a # Descending order (newest first)
      elsif date_a
        -1 # a comes first if it has a date
      elsif date_b
        1 # b comes first if it has a date
      else
        0 # Both nil, maintain order
      end
    end
  end

  def update(updated_at : Time)
    @updated_at = updated_at
    # Invalidate timeline cache when feeds are updated
    @timeline_cache = {items: @timeline_cache[:items], cached_at: Time.local - TIMELINE_CACHE_TTL}
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
