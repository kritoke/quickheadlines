require "./models/article_content"
require "./constants"

module Azurite
  module StoreInterface
    abstract def store(item_link : String, feed_url : String, title : String, content : String, content_type : String = Azurite::Constants::DEFAULT_CONTENT_TYPE) : Bool
    abstract def get_content(item_link : String) : String?
    abstract def get_article(item_link : String) : ArticleContent?
    abstract def articles_for_feed(feed_url : String) : Array(ArticleContent)
    abstract def cleanup_old_entries(retention_days : Int32? = nil) : Int32
    abstract def db_size_mb : Float64
    abstract def enforce_size_limits : Nil
    abstract def start_auto_cleanup(interval : Time::Span = 1.hour) : Nil
    abstract def stop_auto_cleanup : Nil
    abstract def close : Nil
  end
end
