require "../config"
require "../constants"
require "../storage"
require "../color_extractor"
require "./database_service"
require "./content_service"
require "./favicon_sync_service"
require "../websocket"
require "../fetcher/vug_adapter"
require "azurite"
require "./memory_manager_actor"
require "./memory_budget"
require "./task_scheduler"

class AppBootstrap
  @config : Config
  @db_service : DatabaseService
  @feed_cache : FeedCache
  @task_scheduler : TaskScheduler

  getter :db_service, :feed_cache

  def initialize(
    @config : Config,
    @janitor_interval = QuickHeadlines::Constants::JANITOR_INTERVAL,
    @clustering_interval = QuickHeadlines::Constants::CLUSTERING_INTERVAL,
    @cleanup_interval = QuickHeadlines::Constants::CLEANUP_INTERVAL,
    @ws_janitor_interval = QuickHeadlines::Constants::WS_JANITOR_INTERVAL,
  )
    @db_service = DatabaseService.new(@config)
    DatabaseService.instance = @db_service

    @feed_cache = FeedCache.load(@config, @db_service)
    FeedCache.instance = @feed_cache
    Log.for("quickheadlines.app").info { "Loaded #{@feed_cache.size} feeds from cache" }

    FaviconActor.instance.init_storage
    VugAdapter.clear_cache

    cleanup_stale_feeds

    FeedFetcher.instance = FeedFetcher.new(@feed_cache)
    FeedFetcher.load_feeds_from_cache(@config)

    content_db_path = File.join(QuickHeadlines::CacheUtils.get_cache_dir(@config), "content.db")
    content_store = Azurite::Builder.new
      .db_path(content_db_path)
      .retention_days(Azurite::RETENTION_DAYS_DEFAULT)
      .max_size_mb(Azurite::MAX_SIZE_MB_DEFAULT)
      .warning_size_mb(Azurite::WARNING_SIZE_MB_DEFAULT)
      .hard_limit_mb(Azurite::HARD_LIMIT_MB_DEFAULT)
      .max_content_bytes(Azurite::MAX_CONTENT_BYTES_DEFAULT)
      .build
    QuickHeadlines::Services::ContentService.instance = QuickHeadlines::Services::ContentService.new(content_store)
    content_store.cleanup_old_entries
    QuickHeadlines::Services::FeedService.content_store = content_store
    Log.for("quickheadlines.app").info { "Azurite content store initialized: #{content_db_path} (#{content_store.db_size_mb.round(2)}MB)" }

    MemoryManagerActor.instance
    Log.for("quickheadlines.app").info { "Memory management actor initialized" }

    EventBroadcaster.start

    @task_scheduler = TaskScheduler.new(@config, @feed_cache, @db_service,
      clustering_interval: @clustering_interval,
      cleanup_interval: @cleanup_interval,
      ws_janitor_interval: @ws_janitor_interval,
    )

    register_shutdown_handler
  end

  private def register_shutdown_handler
    at_exit do
      Log.for("quickheadlines.app").info { "Shutting down gracefully..." }
      begin
        @db_service.close
      rescue ex : Exception
        Log.for("quickheadlines.app").warn { "Error closing database: #{ex.message}" }
      end
    end
  end

  def start_background_tasks
    @task_scheduler.start_all
  end

  def verify_feeds_loaded
    Log.for("quickheadlines.app").info { "Verifying feeds loaded..." }
    Log.for("quickheadlines.app").debug { "StateStore.feeds.size=#{StateStore.feeds.size}" }
    StateStore.tabs.each do |tab|
      Log.for("quickheadlines.app").debug { "StateStore.tabs[#{tab.name}].feeds.size=#{tab.feeds.size}" }
    end
  end

  private def cleanup_stale_feeds
    config_urls = @config.all_feed_urls
    @feed_cache.cleanup_store.remove_stale_feeds(config_urls)
  rescue ex
    Log.for("quickheadlines.app").warn(exception: ex) { "cleanup_stale_feeds failed on startup" }
  end
end
