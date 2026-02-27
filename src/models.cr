require "mutex"

record Item, title : String, link : String, pub_date : Time?, version : String? = nil
# Add header_theme_colors to TimelineItem so timeline responses can include theme-aware JSON
record TimelineItem, item : Item, feed_title : String, feed_url : String, feed_link : String, favicon : String?, favicon_data : String?, header_color : String?, header_text_color : String?, header_theme_colors : String?

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
  header_theme_colors : String?,
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
    item.header_theme_colors,
    cluster_id,
    is_representative,
    cluster_size
  )
end

# Story grouping result
record StoryGroup,
  representative : ClusteredTimelineItem,
  others : Array(ClusteredTimelineItem)

record FeedData, title : String, url : String, site_link : String, header_color : String?, header_text_color : String?, items : Array(Item), etag : String? = nil, last_modified : String? = nil, favicon : String? = nil, favicon_data : String? = nil, error_message : String? = nil do
  def display_header_color
    (header_color.try(&.strip).presence) || "transparent"
  end

  def display_header_text_color
    header_text_color.try(&.strip).presence
  end

  def display_link
    site_link.empty? ? url : site_link
  end

  # Backwards-compatible accessor for theme-aware header colors.
  # Stored separately from the record initializer to avoid changing many call sites.
  def header_theme_colors : String?
    @header_theme_colors
  end

  def header_theme_colors=(val : String?)
    @header_theme_colors = val
  end

  def failed?
    error_message != nil
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
  property? is_clustering : Bool = false
  property? is_refreshing : Bool = false

  @mutex = Mutex.new
  @timeline_cache = {items: [] of TimelineItem, cached_at: Time.local}
  TIMELINE_CACHE_TTL = 30.seconds

  def feeds_for_tab(tab_name : String)
    tabs.find { |tab| tab.name.downcase == tab_name.downcase }.try(&.feeds) || [] of FeedData
  end

  def releases_for_tab(tab_name : String)
    tabs.find { |tab| tab.name.downcase == tab_name.downcase }.try(&.software_releases) || [] of FeedData
  end

  def with_lock(&)
    @mutex.synchronize { yield }
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
          feed.header_text_color,
          feed.header_theme_colors
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
            feed.header_text_color,
            feed.header_theme_colors
          )
        end
      end
    end

    # Sort by publication date (newest first), items without dates go to end
    items.sort! do |left, right|
      date_left = left.item.pub_date
      date_right = right.item.pub_date
      if date_left && date_right
        date_right <=> date_left # Descending order (newest first)
      elsif date_left
        -1 # left comes first if it has a date
      elsif date_right
        1 # right comes first if it has a date
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

# Immutable state record for functional updates
record AppStateSnapshot,
  feeds : Array(FeedData),
  software_releases : Array(FeedData),
  tabs : Array(Tab),
  updated_at : Time,
  config_title : String,
  config : Config?,
  is_clustering : Bool,
  is_refreshing : Bool

# Thread-safe state store with atomic updates
module StateStore
  @@current = AppStateSnapshot.new(
    feeds: [] of FeedData,
    software_releases: [] of FeedData,
    tabs: [] of Tab,
    updated_at: Time.local,
    config_title: "Quick Headlines",
    config: nil,
    is_clustering: false,
    is_refreshing: false
  )
  @@mutex = Mutex.new

  def self.get : AppStateSnapshot
    @@mutex.synchronize { @@current }
  end

  def self.update(&transform : AppStateSnapshot -> AppStateSnapshot) : AppStateSnapshot
    @@mutex.synchronize do
      @@current = transform.call(@@current)
      @@current
    end
  end

  # Convenience methods for backward compatibility with existing code
  def self.feeds
    get.feeds
  end

  def self.tabs
    get.tabs
  end

  def self.software_releases
    get.software_releases
  end

  def self.updated_at
    get.updated_at
  end

  def self.config
    get.config
  end

  def self.config_title
    get.config_title
  end

  def self.is_clustering?
    get.is_clustering
  end

  def self.is_refreshing?
    get.is_refreshing
  end
end

# Legacy compatibility - delegates to StateStore
class AppState
  def self.feeds
    StateStore.feeds
  end

  def self.tabs
    StateStore.tabs
  end

  def self.software_releases
    StateStore.software_releases
  end

  def self.updated_at
    StateStore.updated_at
  end

  def self.config
    StateStore.config
  end

  def self.config_title
    StateStore.config_title
  end

  def self.config_title=(value : String)
    StateStore.update { |s| s.copy_with(config_title: value) }
  end

  def self.config=(value : Config?)
    StateStore.update { |s| s.copy_with(config: value) }
  end

  def self.feeds=(value : Array(FeedData))
    StateStore.update { |s| s.copy_with(feeds: value) }
  end

  def self.tabs=(value : Array(Tab))
    StateStore.update { |s| s.copy_with(tabs: value) }
  end

  def self.software_releases=(value : Array(FeedData))
    StateStore.update { |s| s.copy_with(software_releases: value) }
  end

  def self.updated_at=(value : Time)
    StateStore.update { |s| s.copy_with(updated_at: value) }
  end

  def self.is_clustering?
    StateStore.is_clustering?
  end

  def self.is_clustering=(value : Bool)
    StateStore.update { |s| s.copy_with(is_clustering: value) }
  end

  def self.is_refreshing?
    StateStore.is_refreshing?
  end

  def self.is_refreshing=(value : Bool)
    StateStore.update { |s| s.copy_with(is_refreshing: value) }
  end

  def self.with_lock(&)
    # Locking is now handled internally by StateStore
    yield
  end

  # Legacy methods that need access to internal state
  def self.feeds_for_tab(tab_name : String)
    StateStore.update { |s| s } # Ensure thread-safe read
    StateStore.feeds_for_tab_impl(tab_name)
  end

  def self.all_timeline_items
    StateStore.update { |s| s } # Ensure thread-safe read
    StateStore.all_timeline_items_impl
  end
end

# Extend StateStore with implementation methods
module StateStore
  def self.feeds_for_tab_impl(tab_name : String) : Array(FeedData)
    tabs.find { |tab| tab.name.downcase == tab_name.downcase }.try(&.feeds) || [] of FeedData
  end

  def self.all_timeline_items_impl : Array(TimelineItem)
    items = [] of TimelineItem

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
          feed.header_text_color,
          feed.header_theme_colors
        )
      end
    end

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
            feed.header_text_color,
            feed.header_theme_colors
          )
        end
      end
    end

    items.sort! do |left, right|
      date_left = left.item.pub_date
      date_right = right.item.pub_date
      if date_left && date_right
        date_right <=> date_left
      elsif date_left
        -1
      elsif date_right
        1
      else
        0
      end
    end

    items
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

FEED_CACHE = if ENV["SKIP_FEED_CACHE_INIT"] == "1"
               nil
             else
               FeedCache.instance
             end
