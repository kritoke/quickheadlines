require "athena"

class Quickheadlines::DTOs::FeedDTO
  include ASR::Serializable

  property id : String
  property title : String
  property url : String
  property site_link : String
  property header_color : String?
  property favicon : String?
  property favicon_data : String?

  def initialize(
    @id : String,
    @title : String,
    @url : String,
    @site_link : String = "",
    @header_color : String? = nil,
    @favicon : String? = nil,
    @favicon_data : String? = nil,
  )
  end

  def self.from_entity(feed : Quickheadlines::Entities::Feed) : Quickheadlines::DTOs::FeedDTO
    new(
      id: feed.id,
      title: feed.title,
      url: feed.url,
      site_link: feed.site_link,
      header_color: feed.header_color,
      favicon: feed.favicon,
      favicon_data: feed.favicon_data
    )
  end
end
