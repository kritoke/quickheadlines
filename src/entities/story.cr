module QuickHeadlines::Entities
  record Story,
    id : String,
    title : String,
    link : String,
    pub_date : Time? = nil,
    feed_title : String = "",
    feed_url : String = "",
    feed_link : String = "",
    favicon : String? = nil,
    favicon_data : String? = nil,
    header_color : String? = nil
end
