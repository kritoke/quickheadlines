require "json"
require "time"

module Azurite
  class ArticleContent
    include JSON::Serializable

    property id : Int64?
    property item_link : String
    property feed_url : String
    property title : String
    property content : String
    property content_type : String
    property fetched_at : Time
    property created_at : Time

    def initialize(
      @item_link : String,
      @feed_url : String,
      @title : String,
      @content : String,
      @content_type : String = "html"
    )
      @fetched_at = Time.utc
      @created_at = Time.utc
    end

    def to_tuple
      {
        item_link: @item_link,
        feed_url: @feed_url,
        title: @title,
        content: @content,
        content_type: @content_type,
        fetched_at: @fetched_at,
        created_at: @created_at
      }
    end
  end
end