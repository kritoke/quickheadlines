require "json"
require "time"
require "../constants"

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
      @content_type : String = Azurite::Constants::DEFAULT_CONTENT_TYPE,
    )
      @fetched_at = Time.utc
      @created_at = Time.utc
    end

    def self.from_row(rs : DB::ResultSet) : ArticleContent
      id = rs.read(Int64)
      item_link = rs.read(String)
      feed_url = rs.read(String)
      title = rs.read(String)
      content = rs.read(String)
      content_type = rs.read(String)
      fetched_at = Time.parse(rs.read(String), "%Y-%m-%dT%H:%M:%SZ", Time::Location::UTC)
      created_at = Time.parse(rs.read(String), "%Y-%m-%dT%H:%M:%SZ", Time::Location::UTC)
      ArticleContent.new(item_link, feed_url, title, content, content_type).tap do |a|
        a.id = id
        a.fetched_at = fetched_at
        a.created_at = created_at
      end
    end
  end
end
