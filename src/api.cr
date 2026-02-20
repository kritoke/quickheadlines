require "json"
require "./models"

# API Response Types for JSON endpoints

# Tab response for API (simple, just name for tab navigation)
class TabResponse
  include JSON::Serializable

  property name : String

  def initialize(@name : String)
  end
end

# Feed response for API
class FeedResponse
  include JSON::Serializable

  @[JSON::Field(emit_null: true)]
  property header_color : String?

  @[JSON::Field(emit_null: true)]
  property header_text_color : String?

  @[JSON::Field(emit_null: true)]
  property header_theme_colors : JSON::Any?

  # Theme-aware header colors (JSON object) - when present this should be preferred by clients
  @[JSON::Field(emit_null: true)]
  property header_theme_colors : JSON::Any?

  property tab : String
  property url : String
  property title : String
  property site_link : String
  property display_link : String

  @[JSON::Field(emit_null: true)]
  property favicon : String?

  @[JSON::Field(emit_null: true)]
  property favicon_data : String?

  property items : Array(ItemResponse)
  property total_item_count : Int32

  @[JSON::Field(emit_null: true)]
  property? has_more : Bool?

  def initialize(
    @tab : String,
    @url : String,
    @title : String,
    @site_link : String,
    @display_link : String,
    @favicon : String? = nil,
    @favicon_data : String? = nil,
    @header_color : String? = nil,
    @header_text_color : String? = nil,
    @header_theme_colors : JSON::Any? = nil,
    @items : Array(ItemResponse) = [] of ItemResponse,
    @total_item_count : Int32 = 0,
    @has_more : Bool? = nil,
  )
  end
end

# Item response for API
class ItemResponse
  include JSON::Serializable

  property title : String
  property link : String
  @[JSON::Field(emit_null: true)]
  property version : String?
  @[JSON::Field(emit_null: true)]
  property pub_date : Int64?

  def initialize(
    @title : String,
    @link : String,
    @version : String? = nil,
    @pub_date : Int64? = nil,
  )
  end
end

# Timeline item response for API
class TimelineItemResponse
  include JSON::Serializable

  property id : String
  property title : String
  property link : String
  property pub_date : Int64?
  property feed_title : String
  property feed_url : String
  property feed_link : String

  @[JSON::Field(emit_null: true)]
  property favicon : String?

  @[JSON::Field(emit_null: true)]
  property favicon_data : String?

  @[JSON::Field(emit_null: true)]
  property header_color : String?

  @[JSON::Field(emit_null: true)]
  property header_text_color : String?

  @[JSON::Field(emit_null: true)]
  property cluster_id : String?

  property? is_representative : Bool

  @[JSON::Field(emit_null: true)]
  property cluster_size : Int32?

  def initialize(
    @id : String,
    @title : String,
    @link : String,
    @pub_date : Int64? = nil,
    @feed_title : String = "",
    @feed_url : String = "",
    @feed_link : String = "",
    @favicon : String? = nil,
    @favicon_data : String? = nil,
    @header_color : String? = nil,
    @header_text_color : String? = nil,
    @header_theme_colors : JSON::Any? = nil,
    @cluster_id : String? = nil,
    @is_representative : Bool = false,
    @cluster_size : Int32? = nil,
  )
  end
end

# Feeds page API response
class FeedsPageResponse
  include JSON::Serializable

  property tabs : Array(TabResponse)
  property active_tab : String
  property feeds : Array(FeedResponse)
  property software_releases : Array(FeedResponse)
  property? is_clustering : Bool = false
  property updated_at : Int64

  def initialize(@tabs : Array(TabResponse), @active_tab : String, @feeds : Array(FeedResponse), @software_releases : Array(FeedResponse), @is_clustering : Bool = false, @updated_at : Int64 = 0_i64)
  end
end

# Timeline page API response
class TimelinePageResponse
  include JSON::Serializable

  property items : Array(TimelineItemResponse)
  property? has_more : Bool
  property total_count : Int32
  property? is_clustering : Bool = false

  def initialize(@items : Array(TimelineItemResponse), @has_more : Bool, @total_count : Int32, @is_clustering : Bool = false)
  end
end

# Version API response
class VersionResponse
  include JSON::Serializable

  property? is_clustering : Bool
  property updated_at : Int64

  def initialize(@updated_at : Int64, @is_clustering : Bool = false)
  end
end

# API Error response
class ApiErrorResponse
  include JSON::Serializable

  property message : String

  def initialize(@message : String)
  end
end

# Story response for API (used in clusters)
class StoryResponse
  include JSON::Serializable

  property id : String
  property title : String
  property link : String
  property pub_date : Int64?
  property feed_title : String
  property feed_url : String
  property feed_link : String

  @[JSON::Field(emit_null: true)]
  property favicon : String?

  @[JSON::Field(emit_null: true)]
  property favicon_data : String?

  @[JSON::Field(emit_null: true)]
  property header_color : String?

  def initialize(
    @id : String,
    @title : String,
    @link : String,
    @pub_date : Int64? = nil,
    @feed_title : String = "",
    @feed_url : String = "",
    @feed_link : String = "",
    @favicon : String? = nil,
    @favicon_data : String? = nil,
    @header_color : String? = nil,
  )
  end
end

# Clusters response for API
class ClustersResponse
  include JSON::Serializable

  property clusters : Array(ClusterResponse)
  property total_count : Int32

  def initialize(@clusters : Array(ClusterResponse), @total_count : Int32 = 0)
  end
end

# Cluster response for API
class ClusterResponse
  include JSON::Serializable

  property id : String
  property representative : StoryResponse
  property others : Array(StoryResponse)
  property cluster_size : Int32

  def initialize(
    @id : String,
    @representative : StoryResponse,
    @others : Array(StoryResponse) = [] of StoryResponse,
    @cluster_size : Int32 = 1,
  )
    @cluster_size = 1 + others.size
  end
end

# Cluster items response for API (individual items in a cluster)
class ClusterItemsResponse
  include JSON::Serializable

  property cluster_id : String
  property items : Array(StoryResponse)

  def initialize(@cluster_id : String, @items : Array(StoryResponse))
  end
end

module Api
  # Convert FeedData to FeedResponse
  def self.feed_to_response(feed : FeedData, tab_name : String = "", total_count : Int32? = nil, display_item_limit : Int32? = nil) : FeedResponse
    cache = FeedCache.instance

    # Prefer freshly extracted colors from FeedData over database cache
    # FeedData.header_color contains colors extracted during this refresh cycle
    # Database colors are used as fallback for feeds without fresh colors
    header_color = feed.header_color
    header_text_color = feed.header_text_color

    # Fall back to database only if FeedData doesn't have colors
    header_theme_colors_json = nil.as(String?)
    if header_color.nil? || header_text_color.nil?
      colors = cache.get_header_colors(feed.url)
      header_color ||= colors[:bg_color]
      header_text_color ||= colors[:text_color]
    end

    # Try to get theme-aware JSON from DB (preferred). This is a JSON string stored in feeds.header_theme_colors
    begin
      theme_json = cache.get_feed_theme_colors(feed.url)
      header_theme_colors_json = theme_json if theme_json && !theme_json.empty?
    rescue
      header_theme_colors_json = nil
    end

    # Limit items for initial display (controls how many items are shown in feed cards)
    limit = display_item_limit || 20

    # Sort items by pub_date (newest first) before limiting
    sorted_items = feed.items.sort_by do |item|
      # Items with pub_date come first, sorted newest to oldest
      # Items without pub_date come last
      item.pub_date.try(&.to_unix) || Int64::MIN
    end.reverse!

    displayed_items = sorted_items.first(limit)

    items_response = displayed_items.map do |item|
      ItemResponse.new(
        title: item.title,
        link: item.link,
        version: item.version,
        pub_date: item.pub_date.try(&.to_unix_ms)
      )
    end

    FeedResponse.new(
      tab: tab_name,
      url: feed.url,
      title: feed.title,
      site_link: feed.site_link,
      display_link: feed.display_link,
      favicon: feed.favicon,
      favicon_data: feed.favicon_data,
      header_color: header_color,
      header_text_color: header_text_color,
      header_theme_colors: header_theme_colors_json ? JSON.parse(header_theme_colors_json) : nil,
      items: items_response,
      total_item_count: total_count || feed.items.size.to_i32
    )
  end

  # Convert Tab to TabResponse
  def self.tab_to_response(tab : Tab, feeds : Array(FeedData), releases : Array(FeedData)) : TabResponse
    feeds_response = feeds.map { |feed| feed_to_response(feed) }
    releases_response = releases.map { |feed| feed_to_response(feed) }

    TabResponse.new(
      name: tab.name,
      feeds: feeds_response,
      software_releases: releases_response
    )
  end

  # Convert TimelineItem to TimelineItemResponse
  def self.timeline_item_to_response(item : TimelineItem) : TimelineItemResponse
    # Look up cluster info from FeedCache (same logic as server.cr add_cluster_info)
    cache = FeedCache.instance
    item_id = cache.get_item_id(item.feed_url, item.item.link)

    cluster_id = nil
    cluster_size = nil
    is_representative = true

    if item_id
      cluster_id = cache.db.query_one?("SELECT cluster_id FROM items WHERE id = ?", item_id, as: {Int64?})
      cluster_size = cache.get_cluster_size(item_id)
      is_representative = cache.cluster_representative?(item_id)
    end

    # Convert cluster_id from Int64? to String? for JSON API
    cluster_id_str = cluster_id.try(&.to_s)

    TimelineItemResponse.new(
      id: generate_item_id(item),
      title: item.item.title,
      link: item.item.link,
      pub_date: item.item.pub_date.try(&.to_unix_ms),
      feed_title: item.feed_title,
      feed_url: item.feed_url,
      feed_link: item.feed_link,
      favicon: item.favicon,
      favicon_data: item.favicon_data,
      header_color: item.header_color,
      header_text_color: item.header_text_color,
      header_theme_colors: item.header_theme_colors ? (JSON.parse(item.header_theme_colors) rescue nil) : nil,
      cluster_id: cluster_id_str,
      is_representative: is_representative,
      cluster_size: cluster_size
    )
  end

  # Generate unique ID for timeline item
  private def self.generate_item_id(item : TimelineItem) : String
    "#{item.feed_url}::#{item.item.link}"
  end

  # Convert Time to Unix milliseconds
  def self.to_unix_ms(time : Time) : Int64
    time.to_unix_ms
  end

  # Send JSON response
  def self.send_json(context : HTTP::Server::Context, data : JSON::Serializable)
    context.response.content_type = "application/json; charset=utf-8"
    context.response.headers["Cache-Control"] = "public, max-age=30"
    context.response.print data.to_json
  end

  # Send error response
  def self.send_error(context : HTTP::Server::Context, message : String)
    error_response = ApiErrorResponse.new(message: message)
    context.response.content_type = "application/json; charset=utf-8"
    context.response.status_code = 500
    context.response.print error_response.to_json
  end

  # Handle /api/feeds endpoint
  def self.handle_feeds(context : HTTP::Server::Context)
    # Get tab from query params, default to "all" if empty or not present
    raw_tab = context.request.query_params["tab"]?
    active_tab = raw_tab.presence || "all"

    # Build simple tabs response (just names for tab navigation)
    tabs_response = STATE.tabs.map do |tab|
      TabResponse.new(name: tab.name)
    end

    if config = STATE.config
      if config.debug?
        STDERR.puts "[#{Time.local}] handle_feeds: active_tab=#{active_tab}, STATE.feeds.size=#{STATE.feeds.size}, STATE.tabs.size=#{STATE.tabs.size}"
        STATE.tabs.each do |tab|
          STDERR.puts "[#{Time.local}] handle_feeds: tab '#{tab.name}' has #{tab.feeds.size} feeds"
        end
      end
    end

    # Get feeds for active tab (flattened to top level)
    # For "all" tab, aggregate feeds from all tabs + top-level feeds
    feeds_response = if active_tab.downcase == "all"
                       # Build list of tuples (feed, tab_name) to preserve tab info
                       all_feeds_with_tabs = [] of {feed: FeedData, tab_name: String}

                       # Top-level feeds have empty tab name
                       STATE.feeds.each do |feed|
                         all_feeds_with_tabs << {feed: feed, tab_name: ""}
                       end

                       # Tab feeds have their tab name
                       STATE.tabs.each do |tab|
                         tab.feeds.each do |feed|
                           all_feeds_with_tabs << {feed: feed, tab_name: tab.name}
                         end
                       end

                       if config = STATE.config
                         if config.debug?
                           STDERR.puts "[DEBUG] handle_feeds: tab=#{active_tab}, top_level_feeds=#{STATE.feeds.size}, tab_count=#{STATE.tabs.size}, total_feeds=#{all_feeds_with_tabs.size}"
                         end
                       end
                       all_feeds_with_tabs.map { |entry| feed_to_response(entry[:feed], entry[:tab_name]) }
                     else
                       active_feeds = STATE.feeds_for_tab(active_tab)
                       if config = STATE.config
                         if config.debug?
                           STDERR.puts "[DEBUG] handle_feeds: tab=#{active_tab}, feeds=#{active_feeds.size}"
                         end
                       end
                       active_feeds.map { |feed| feed_to_response(feed, active_tab) }
                     end

    response = FeedsPageResponse.new(
      tabs: tabs_response,
      active_tab: active_tab,
      feeds: feeds_response,
      is_clustering: STATE.is_clustering?
    )

    send_json(context, response)
  end

  # Handle /api/feed_more endpoint
  def self.handle_feed_more(context : HTTP::Server::Context)
    url = context.request.query_params["url"]?
    limit = context.request.query_params["limit"]?.try(&.to_i?) || 10
    offset = context.request.query_params["offset"]?.try(&.to_i?) || 0

    if url.nil?
      send_error(context, "Missing 'url' parameter")
      return
    end

    # Search top-level feeds and all feeds within tabs
    config = STATE.config
    if config.nil?
      send_error(context, "Configuration not loaded")
      return
    end

    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)

    if feed_config = all_feeds.find { |feed| feed.url == url }
      cache = FeedCache.instance

      # Check if we have enough data in the cache
      current_count = 0
      if cached_feed = cache.get(url)
        current_count = cached_feed.items.size
      end

      needed_count = offset + limit

      # Fetch more data if needed
      if current_count < needed_count
        fetch_feed(feed_config, needed_count + 50, nil)
      end

      # Get items from cache
      if data = cache.get(url)
        max_index = Math.min(offset + limit, data.items.size)
        trimmed_items = data.items[0...max_index]

        items_response = trimmed_items.map do |item|
          ItemResponse.new(
            title: item.title,
            link: item.link,
            version: item.version,
            pub_date: item.pub_date.try(&.to_unix_ms)
          )
        end

        response = FeedResponse.new(
          tab: "",
          url: data.url,
          title: data.title,
          site_link: data.site_link,
          display_link: data.display_link,
          favicon: data.favicon,
          favicon_data: data.favicon_data,
          header_color: data.header_color,
          header_text_color: data.header_text_color,
          items: items_response,
          total_item_count: trimmed_items.size.to_i32
        )

        send_json(context, response)
      else
        send_error(context, "Failed to retrieve feed data")
      end
    else
      context.response.status_code = 404
      send_error(context, "Feed not found")
    end
  end

  # Handle /api/timeline endpoint
  def self.handle_timeline(context : HTTP::Server::Context)
    limit = context.request.query_params["limit"]?.try(&.to_i?) || 100
    offset = context.request.query_params["offset"]?.try(&.to_i?) || 0

    # Get all timeline items
    all_items = STATE.all_timeline_items

    # Ensure timeline items are strictly sorted by publication date (newest first).
    # This re-sorting guards against any upstream ordering issues and ensures the
    # UI always receives items in descending pub_date order.
    all_items.sort! do |left, right|
      da = left.item.pub_date ? left.item.pub_date.to_unix_ms : 0_i64
      db = right.item.pub_date ? right.item.pub_date.to_unix_ms : 0_i64
      db <=> da
    end

    total_count = all_items.size
    max_index = Math.min(offset + limit, total_count)
    raw_items = all_items[offset...max_index]

    # Convert to timeline item responses
    items_response = raw_items.map do |item|
      timeline_item_to_response(item)
    end

    has_more = offset + limit < total_count

    response = TimelinePageResponse.new(
      items: items_response,
      has_more: has_more,
      total_count: total_count.to_i32,
      is_clustering: STATE.is_clustering?
    )

    send_json(context, response)
  end

  # Handle /api/version endpoint
  def self.handle_version(context : HTTP::Server::Context)
    response = VersionResponse.new(
      updated_at: STATE.updated_at.to_unix_ms,
      is_clustering: STATE.is_clustering?
    )
    send_json(context, response)
  end
end
