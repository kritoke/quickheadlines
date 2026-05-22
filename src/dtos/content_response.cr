require "json"

module QuickHeadlines::DTOs
  class ContentResponse
    include JSON::Serializable

    property content : String?
    property content_type : String?
    property error : String?
    property is_summary : Bool = false
    property article_url : String? = nil

    def initialize(
      @content : String? = nil,
      @content_type : String? = nil,
      @error : String? = nil,
      @is_summary : Bool = false,
      @article_url : String? = nil
    )
    end
  end
end
