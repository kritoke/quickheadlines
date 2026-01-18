require "athena"

module Quickheadlines::Entities
  class Feed
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
      @favicon_data : String? = nil
    )
    end
  end
end
