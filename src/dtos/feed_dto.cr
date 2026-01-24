require "athena"

class Quickheadlines::DTOs::FeedDTO
  include ASR::Serializable

  @[ASRA::Name("id")]
  property id : String

  @[ASRA::Name("title")]
  property title : String

  @[ASRA::Name("url")]
  property url : String

  @[ASRA::Name("siteLink")]
  property site_link : String

  @[ASRA::Name("headerColor")]
  property header_color : String?

  @[ASRA::Name("favicon")]
  property favicon : String?

  @[ASRA::Name("faviconData")]
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
