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

# Tabs list response for /api/tabs endpoint
class TabsResponse
  include JSON::Serializable

  property tabs : Array(TabResponse)

  def initialize(@tabs : Array(TabResponse))
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
  @[JSON::Field(emit_null: true)]
  property comment_url : String?
  @[JSON::Field(emit_null: true)]
  property commentary_url : String?

  def initialize(
    @title : String,
    @link : String,
    @version : String? = nil,
    @pub_date : Int64? = nil,
    @comment_url : String? = nil,
    @commentary_url : String? = nil,
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
  property? clustering : Bool = false
  property updated_at : Int64

  def initialize(@tabs : Array(TabResponse), @active_tab : String, @feeds : Array(FeedResponse), @software_releases : Array(FeedResponse), @clustering : Bool = false, @updated_at : Int64 = 0_i64)
  end
end

# Timeline page API response
class TimelinePageResponse
  include JSON::Serializable

  property items : Array(TimelineItemResponse)
  property? has_more : Bool
  property total_count : Int32
  property? clustering : Bool = false

  def initialize(@items : Array(TimelineItemResponse), @has_more : Bool, @total_count : Int32, @clustering : Bool = false)
  end
end

# Version API response
class VersionResponse
  include JSON::Serializable

  property? clustering : Bool
  property updated_at : Int64

  def initialize(@updated_at : Int64, @clustering : Bool = false)
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

# Cluster items response for API (individual items in a cluster)
class ClusterItemsResponse
  include JSON::Serializable

  property cluster_id : String
  property items : Array(StoryResponse)

  def initialize(@cluster_id : String, @items : Array(StoryResponse))
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
    @cluster_size : Int32 = 0,
  )
    @cluster_size = @cluster_size > 0 ? @cluster_size : 1 + others.size
  end
end

module Api
  def self.feed_to_response(feed : FeedData, tab_name : String = "", total_count : Int32? = nil, display_item_limit : Int32? = nil) : FeedResponse
    cache = FeedCache.instance

    header_color = feed.header_color
    header_text_color = feed.header_text_color

    header_theme_colors_json = nil.as(String?)
    if header_color.nil? || header_text_color.nil?
      colors = cache.get_header_colors(feed.url)
      header_color ||= colors[:bg_color]
      header_text_color ||= colors[:text_color]
    end

    begin
      theme_json = cache.get_feed_theme_colors(feed.url)
      header_theme_colors_json = theme_json if theme_json && !theme_json.empty?
    rescue DB::Error | JSON::ParseException
      header_theme_colors_json = nil
    end

    limit = display_item_limit || 20

    displayed_items = feed.items.first(limit)

    items_response = displayed_items.map do |item|
      ItemResponse.new(
        title: item.title,
        link: item.link,
        version: item.version,
        pub_date: item.pub_date.try(&.to_unix_ms),
        comment_url: item.comment_url,
        commentary_url: item.commentary_url
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
end
