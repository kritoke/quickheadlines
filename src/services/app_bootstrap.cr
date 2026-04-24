require "../config"
require "../constants"
require "../storage"
require "./database_service"
require "./favicon_sync_service"
require "../favicon_cache"
require "../websocket"
require "../fetcher/vug_adapter"

class AppBootstrap
  @config : Config
  @db_service : DatabaseService
  @feed_cache : FeedCache
  @janitor_interval : Time::Span
  @clustering_interval : Time::Span
  @cleanup_interval : Time::Span
  @ws_janitor_interval : Time::Span

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

    @feed_cache = load_feed_cache(@config, @db_service)
    Log.for("quickheadlines.app").info { "Loaded #{@feed_cache.size} feeds from cache" }

    FaviconStorage.init
    warmed = FaviconCache.warm_from_dir(FaviconStorage.favicon_dir)
    Log.for("quickheadlines.app").info { "Warmed favicon cache with #{warmed} entries" } if warmed > 0
    VugAdapter.clear_cache

    cleanup_stale_feeds

    FeedFetcher.load_feeds_from_cache(@config)

    EventBroadcaster.start

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
    run_startup_maintenance
    start_feed_refresh
    start_clustering_scheduler
    start_cleanup_scheduler
    start_ws_janitor
    run_initial_clustering
  end

  def verify_feeds_loaded
    Log.for("quickheadlines.app").info { "Verifying feeds loaded..." }
    Log.for("quickheadlines.app").debug { "StateStore.feeds.size=#{StateStore.feeds.size}" }
    StateStore.tabs.each do |tab|
      Log.for("quickheadlines.app").debug { "StateStore.tabs[#{tab.name}].feeds.size=#{tab.feeds.size}" }
    end
  end

  private def run_startup_maintenance
    spawn do
      begin
        @feed_cache.normalize_pub_dates
      rescue ex
        Log.for("quickheadlines.app").warn(exception: ex) { "normalize_pub_dates failed on startup" }
      end

      db_size = get_db_size(@feed_cache.db_path)
      if db_size > QuickHeadlines::Constants::DB_VACUUM_THRESHOLD
        begin
          @feed_cache.vacuum
        rescue ex
          Log.for("quickheadlines.app").warn(exception: ex) { "startup vacuum failed" }
        end
      end

      begin
        FaviconSyncService.new(@feed_cache.db).sync_favicon_paths
      rescue ex
        Log.for("quickheadlines.app").warn(exception: ex) { "favicon sync failed on startup" }
      end
    end
  end

  private def start_feed_refresh
    spawn do
      start_refresh_loop("feeds.yml", @feed_cache, @db_service)
    end
  end

  private def start_clustering_scheduler
    spawn do
      loop do
        sleep @clustering_interval
        break if QuickHeadlines.shutting_down?
        if start_time = StateStore.clustering_start_time
          if Time.utc - start_time > QuickHeadlines::Constants::STUCK_CLUSTER_THRESHOLD
            Log.for("quickheadlines.app").warn { "Clustering stuck for >4 hours, resetting state" }
            StateStore.clustering = false
          end
        end
        next if StateStore.clustering?
        threshold = StateStore.config.try(&.clustering).try(&.threshold) || 0.35
        QuickHeadlines::Services::ClusteringService.new(@db_service).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
      end
    end
  end

  private def run_initial_clustering
    run_on_startup = @config.clustering.try(&.run_on_startup?)
    if run_on_startup != false
      spawn do
        sleep QuickHeadlines::Constants::INITIAL_CLUSTER_DELAY
        begin
          Log.for("quickheadlines.app").info { "Running initial clustering on startup..." }
          threshold = @config.clustering.try(&.threshold) || 0.35
          QuickHeadlines::Services::ClusteringService.new(@db_service).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Initial clustering failed" }
        end
      end
    end
  end

  private def start_cleanup_scheduler
    spawn do
      loop do
        sleep @cleanup_interval
        break if QuickHeadlines.shutting_down?
        begin
          VugAdapter.clear_cache
          Log.for("quickheadlines.app").debug { "Cleared Vug cache" }
          @feed_cache.cleanup_old_articles(QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
          @feed_cache.cleanup_old_entries(@config.cache_retention_hours || QuickHeadlines::Constants::CACHE_RETENTION_HOURS)
          Log.for("quickheadlines.app").debug { "Scheduled cleanup completed" }
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Scheduled cleanup failed" }
        end
      end
    end
  end

  private def start_ws_janitor
    spawn do
      loop do
        sleep @ws_janitor_interval
        break if QuickHeadlines.shutting_down?
        begin
          removed = SocketManager.instance.cleanup_dead_connections
          stats = SocketManager.instance.stats
          Log.for("quickheadlines.websocket").debug do
            "Janitor: #{stats["connections"]} active, #{removed} removed, " \
            "#{stats["messages_sent"]} sent, #{stats["messages_dropped"]} dropped, " \
            "#{stats["send_errors"]} errors"
          end
        rescue ex
          Log.for("quickheadlines.websocket").error(exception: ex) { "Janitor failed" }
        end
      end
    end
  end

  private def cleanup_stale_feeds
    config_urls = @config.all_feed_urls
    @feed_cache.remove_stale_feeds(config_urls)
  rescue ex
    Log.for("quickheadlines.app").warn(exception: ex) { "cleanup_stale_feeds failed on startup" }
  end
end
