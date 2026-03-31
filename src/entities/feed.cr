require "athena"

module QuickHeadlines::Entities
  record Feed,
    id : String,
    title : String,
    url : String,
    site_link : String = "",
    header_color : String? = nil,
    header_text_color : String? = nil,
    favicon : String? = nil,
    favicon_data : String? = nil
end
