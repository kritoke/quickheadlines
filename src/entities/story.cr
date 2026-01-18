require "athena"

module Quickheadlines::Entities
  class Story
    property id : String
    property title : String
    property link : String
    property pub_date : Time?
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
      @pub_date : Time? = nil,
      @feed_title : String = "",
      @feed_url : String = "",
      @feed_link : String = "",
      @favicon : String? = nil,
      @favicon_data : String? = nil,
      @header_color : String? = nil,
    )
    end
  end
end
