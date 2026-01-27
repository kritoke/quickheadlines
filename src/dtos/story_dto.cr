require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::StoryDTO
  include ASR::Serializable

  property id : String

  property title : String

  property link : String

  property pub_date : Int64?

  property feed_title : String

  property feed_url : String

  property feed_link : String

  property favicon : String?

  property favicon_data : String?

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
