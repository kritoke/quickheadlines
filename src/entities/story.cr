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
    header_color : String? = nil,
    header_text_color : String? = nil,
    comment_url : String? = nil,
    commentary_url : String? = nil
end
