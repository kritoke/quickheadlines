require "json"

module QuickHeadlines::DTOs
  class ContentResponse
    include JSON::Serializable

    property content : String?
    property content_type : String?
    property error : String?

    def initialize(@content : String? = nil, @content_type : String? = nil, @error : String? = nil)
    end
  end
end
