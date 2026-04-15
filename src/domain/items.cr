module QuickHeadlines::Domain
  record TimelineEntry,
    id : Int64,
    title : String,
    link : String,
    pub_date : Time?,
    feed_title : String,
    feed_url : String,
    feed_link : String,
    favicon : String?,
    header_color : String?,
    header_text_color : String?,
    cluster_id : Int64?,
    representative : Bool,
    cluster_size : Int32,
    comment_url : String? = nil,
    commentary_url : String? = nil
end
