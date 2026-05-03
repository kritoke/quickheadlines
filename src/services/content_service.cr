require "azurite"

module QuickHeadlines::Services
  class ContentService
    @@instance : ContentService?

    def self.instance : ContentService
      @@instance || raise "ContentService: Not initialized. AppBootstrap must create ContentService before accessing instance."
    end

    def self.instance=(service : ContentService)
      @@instance = service
    end

    @store : Azurite::Store

    def initialize(@store : Azurite::Store)
    end

    def get_content(item_link : String) : String?
      @store.get_content(item_link)
    end

    def store_content(item_link : String, feed_url : String, title : String, content : String) : Bool
      @store.store(item_link, feed_url, title, content)
    end

    def get_content_with_info(item_link : String) : Azurite::ArticleContent?
      @store.get_article(item_link)
    end

    def check_size_and_cleanup
      @store.enforce_size_limits
    end

    def cleanup_old_entries(retention_days : Int32 = Azurite::RETENTION_DAYS_DEFAULT) : Int32
      @store.cleanup_old_entries(retention_days)
    end

    def db_size_mb : Float64
      @store.db_size_mb
    end
  end
end