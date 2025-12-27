record Item, title : String, link : String, pub_date : Time?, version : String? = nil
record FeedData, title : String, url : String, site_link : String, header_color : String?, items : Array(Item), etag : String? = nil, last_modified : String? = nil, favicon : String? = nil, favicon_data : String? = nil do
  def display_header_color
    (header_color.try(&.strip).presence) || "transparent"
  end

  def display_link
    site_link.empty? ? url : site_link
  end
end

class AppState
  property feeds = [] of FeedData
  property updated_at = Time.local
  property config_title = "Quick Headlines"
  property config : Config?

  def update(feeds : Array(FeedData), updated_at : Time)
    @feeds = feeds
    @updated_at = updated_at
  end
end

STATE = AppState.new
