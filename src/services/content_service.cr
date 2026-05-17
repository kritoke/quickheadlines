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
      # Wrap Azurite store with small retry/backoff to mitigate transient SQLITE_BUSY errors
      max_retries = 3
      attempt = 0
      begin
        attempt += 1
        return @store.store(item_link, feed_url, title, content)
      rescue DB::Error, SQLite3::Exception => ex
        if attempt <= max_retries
          backoff = (0.1 * (2 ** (attempt - 1))).to_f
          Log.for("quickheadlines.azurite").warn { "ContentService.store_content: transient DB error on attempt #{attempt}/#{max_retries} for #{item_link} - #{ex.message}; retrying in #{backoff}s" }
          sleep backoff
          retry
        else
          Log.for("quickheadlines.azurite").error(exception: ex) { "ContentService.store_content: failed to store content for #{item_link} after #{max_retries} attempts" }
          raise
        end
      rescue ex
        # Unexpected exception - log and re-raise
        Log.for("quickheadlines.azurite").error(exception: ex) { "ContentService.store_content: unexpected error storing content for #{item_link}: #{ex.class} - #{ex.message}" }
        raise
      end
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
