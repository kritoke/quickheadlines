require "athena"

class Quickheadlines::DTOs::StoryDTO
  include ASR::Serializable

  @[ASRA::Name("id")]
  property id : String

  @[ASRA::Name("title")]
  property title : String

  @[ASRA::Name("link")]
  property link : String

  @[ASRA::Name("pubDate")]
  property pub_date : Int64?

  @[ASRA::Name("feedTitle")]
  property feed_title : String

  @[ASRA::Name("feedUrl")]
  property feed_url : String

  @[ASRA::Name("feedLink")]
  property feed_link : String

  @[ASRA::Name("favicon")]
  property favicon : String?

  @[ASRA::Name("faviconData")]
  property favicon_data : String?

  @[ASRA::Name("headerColor")]
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

  def self.from_entity(story : Quickheadlines::Entities::Story) : Quickheadlines::DTOs::StoryDTO
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
      header_color: story.header_color
    )
  end
end
