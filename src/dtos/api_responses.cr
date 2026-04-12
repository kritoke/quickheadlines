require "json"
require "../models"

class TabResponse
  include JSON::Serializable

  property name : String

  def initialize(@name : String)
  end
end

class TabsResponse
  include JSON::Serializable

  property tabs : Array(TabResponse)

  def initialize(@tabs : Array(TabResponse))
  end
end

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

  @[JSON::Field(emit_null: true)]
  property comment_url : String?

  @[JSON::Field(emit_null: true)]
  property commentary_url : String?

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
    @comment_url : String? = nil,
    @commentary_url : String? = nil,
  )
  end
end

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

class TimelinePageResponse
  include JSON::Serializable

  property items : Array(TimelineItemResponse)
  property? has_more : Bool
  property total_count : Int32
  property? clustering : Bool = false

  def initialize(@items : Array(TimelineItemResponse), @has_more : Bool, @total_count : Int32, @clustering : Bool = false)
  end
end

class VersionResponse
  include JSON::Serializable

  property? clustering : Bool
  property updated_at : Int64

  def initialize(@updated_at : Int64, @clustering : Bool = false)
  end
end

class ApiErrorResponse
  include JSON::Serializable

  property message : String

  def initialize(@message : String)
  end
end

class ClusterItemsResponse
  include JSON::Serializable

  property cluster_id : String
  property items : Array(QuickHeadlines::DTOs::StoryResponse)

  def initialize(@cluster_id : String, @items : Array(QuickHeadlines::DTOs::StoryResponse))
  end
end
