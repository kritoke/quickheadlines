require "json"

class QuickHeadlines::DTOs::StoryResponse
  include JSON::Serializable

  property id : String
  property title : String
  property link : String
  @[JSON::Field(emit_null: true)]
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
    @comment_url : String? = nil,
    @commentary_url : String? = nil,
  )
  end

  def self.from_entity(story : QuickHeadlines::Entities::Story) : QuickHeadlines::DTOs::StoryResponse
    new(
      id: story.id,
      title: story.title,
      link: story.link,
      pub_date: story.pub_date.try(&.to_unix_ms),
      feed_title: story.feed_title,
      feed_url: story.feed_url,
      feed_link: story.feed_link,
      favicon: story.favicon,
      favicon_data: story.favicon_data,
      header_color: story.header_color,
      header_text_color: story.header_text_color,
      comment_url: story.comment_url,
      commentary_url: story.commentary_url,
    )
  end
end
