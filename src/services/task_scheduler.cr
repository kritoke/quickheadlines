require "../config"
require "../constants"
require "../services/fiber_tracker"
require "../fetcher/interruptible_sleep"
require "../fetcher/refresh_loop"
require "./memory_manager"

# Schedules and manages background fibers for periodic tasks.
# Extracted from AppBootstrap to separate initialization from scheduling.
class TaskScheduler
  @config : Config
  @feed_cache : FeedCache
  @db_service : DatabaseService
  @clustering_interval : Time::Span
  @cleanup_interval : Time::Span
  @ws_janitor_interval : Time::Span

  def initialize(
    @config : Config,
    @feed_cache : FeedCache,
    @db_service : DatabaseService,
    @clustering_interval = QuickHeadlines::Constants::CLUSTERING_INTERVAL,
    @cleanup_interval = QuickHeadlines::Constants::CLEANUP_INTERVAL,
    @ws_janitor_interval = QuickHeadlines::Constants::WS_JANITOR_INTERVAL,
  )
  end

  def start_all
    run_startup_maintenance
    start_feed_refresh
    start_clustering_scheduler
    start_cleanup_scheduler
    start_ws_janitor
    run_initial_clustering
  end

  private def run_startup_maintenance
    RefreshLoop::FiberTracker.tracked_spawn do
      begin
        @feed_cache.cleanup_store.normalize_pub_dates
      rescue ex
        Log.for("quickheadlines.app").warn(exception: ex) { "normalize_pub_dates failed on startup" }
      end

      db_size = QuickHeadlines::CacheUtils.get_db_size(@feed_cache.db_path)
      if db_size > QuickHeadlines::Constants::DB_VACUUM_THRESHOLD
        begin
          @feed_cache.cleanup_store.vacuum
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
    RefreshLoop::FiberTracker.tracked_spawn do
      RefreshLoop.start("feeds.yml", @feed_cache, @db_service)
    rescue ex
      Log.for("quickheadlines.app").error(exception: ex) { "start_feed_refresh failed" }
    end
  end

  private def start_clustering_scheduler
    RefreshLoop::FiberTracker.tracked_spawn do
      loop do
        RefreshLoop::InterruptibleSleep.sleep(@clustering_interval)
        break if QuickHeadlines.shutting_down?
        threshold = @config.clustering.try(&.threshold) || 0.35
        QuickHeadlines::Services::ClusteringService.new(@db_service, nil, @config.clustering).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
      rescue ex
        Log.for("quickheadlines.app").error(exception: ex) { "Clustering scheduler iteration failed" }
      end
    end
  end

  private def run_initial_clustering
    run_on_startup = @config.clustering.try(&.run_on_startup?)
    if run_on_startup != false
      RefreshLoop::FiberTracker.tracked_spawn do
        RefreshLoop::InterruptibleSleep.sleep(QuickHeadlines::Constants::INITIAL_CLUSTER_DELAY)
        begin
          Log.for("quickheadlines.app").info { "Running initial clustering on startup..." }
          threshold = @config.clustering.try(&.threshold) || 0.35
          QuickHeadlines::Services::ClusteringService.new(@db_service, nil, @config.clustering).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Initial clustering failed" }
        end
      end
    end
  end

  private def start_cleanup_scheduler
    RefreshLoop::FiberTracker.tracked_spawn do
      loop do
        RefreshLoop::InterruptibleSleep.sleep(@cleanup_interval)
        break if QuickHeadlines.shutting_down?
        begin
          MemoryManager.clear_caches
          @feed_cache.cleanup_store.cleanup_old_articles(QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
          @feed_cache.cleanup_store.cleanup_old_entries(@config.cache_retention_hours || QuickHeadlines::Constants::CACHE_RETENTION_HOURS)
          QuickHeadlines::Services::ContentService.instance.check_size_and_cleanup
          Log.for("quickheadlines.app").debug { "Scheduled cleanup completed" }
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Scheduled cleanup failed" }
        end
      end
    end
  end

  private def start_ws_janitor
    RefreshLoop::FiberTracker.tracked_spawn do
      loop do
        RefreshLoop::InterruptibleSleep.sleep(@ws_janitor_interval)
        break if QuickHeadlines.shutting_down?
        begin
          removed = SocketManager.instance.cleanup_dead_connections
          stats = SocketManager.instance.connection_stats
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
end
