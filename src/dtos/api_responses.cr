require "json"
require "../models"

module QuickHeadlines::DTOs
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
    property content : String?
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
      @content : String? = nil,
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

    @[JSON::Field(emit_null: true)]
    property content : String?

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
      @cluster_id : String? = nil,
      @is_representative : Bool = false,
      @cluster_size : Int32? = nil,
      @comment_url : String? = nil,
      @commentary_url : String? = nil,
      @content : String? = nil,
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

  class ClusterItemsResponse
    include JSON::Serializable

    property cluster_id : String
    property items : Array(StoryResponse)

    def initialize(@cluster_id : String, @items : Array(StoryResponse))
    end
  end

  class AdminStatusResponse
    include JSON::Serializable

    property? clustering : Bool
    property? refreshing : Bool
    property active_jobs : Int32
    property websocket_connections : Int32
    property websocket_messages_sent : Int64
    property websocket_messages_dropped : Int64
    property websocket_send_errors : Int64
    property websocket_connections_closed : Int64
    property broadcaster_processed : Int64

    def initialize(
      @clustering : Bool,
      @refreshing : Bool,
      @active_jobs : Int32 = 0,
      @websocket_connections : Int32 = 0,
      @websocket_messages_sent : Int64 = 0_i64,
      @websocket_messages_dropped : Int64 = 0_i64,
      @websocket_send_errors : Int64 = 0_i64,
      @websocket_connections_closed : Int64 = 0_i64,
      @broadcaster_processed : Int64 = 0_i64,
    )
    end
  end

  class AdminVersionResponse
    include JSON::Serializable

    property updated_at : Int64
    property? clustering : Bool

    def initialize(@updated_at : Int64, @clustering : Bool)
    end
  end

  class AdminActionResponse
    include JSON::Serializable

    property status : String
    property message : String

    def initialize(@status : String, @message : String)
    end
  end

  class HeaderColorResponse
    include JSON::Serializable

    property status : String

    def initialize(@status : String)
    end
  end
end
