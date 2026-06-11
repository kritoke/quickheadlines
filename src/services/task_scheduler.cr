require "../config"
require "../constants"
require "../services/fiber_tracker"
require "../fetcher/interruptible_sleep"
require "../fetcher/refresh_loop"
require "../fetcher/monitoring"
require "./memory_manager_actor"

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
    start_watchdog
  end

  # Watchdog fiber to detect stuck refresh loops and attempt recovery.
  private def start_watchdog : Nil
    RefreshLoop::FiberTracker.tracked_spawn do
      consecutive = 0
      loop do
        begin
          break if QuickHeadlines.shutting_down?
          RefreshLoop::InterruptibleSleep.sleep(QuickHeadlines::Constants::WATCHDOG_INTERVAL_SECONDS)

          config = StateStore.config
          stuck_threshold = stuck_threshold_seconds(config)

          unless RefreshLoop::Monitoring.stuck?(stuck_threshold)
            consecutive = 0
            next
          end

          consecutive += 1
          Log.for("quickheadlines.watchdog").warn { "Watchdog: detected stuck refresh (count=#{consecutive})" }
          next if consecutive < QuickHeadlines::Constants::WATCHDOG_DEBOUNCE_COUNT

          consecutive = watchdog_recover(config, consecutive)
        rescue ex
          Log.for("quickheadlines.watchdog").error(exception: ex) { "Watchdog fiber error" }
        end
      end
    end
  end

  private def stuck_threshold_seconds(config : Config?) : Int32
    refresh_minutes = config.try(&.refresh_minutes) || 10
    (refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE) * 3
  end

  private def watchdog_recover(config : Config?, consecutive : Int32) : Int32
    Log.for("quickheadlines.watchdog").info { "Watchdog: attempting recovery (attempting atomic recovery)" }

    if RefreshLoop::Monitoring.attempt_recovery
      Log.for("quickheadlines.watchdog").info { "Watchdog: atomic recovery succeeded, repopulating StateStore from cache" }
      if config && FeedFetcher.load_feeds_from_cache(config)
        Log.for("quickheadlines.watchdog").info { "Watchdog: successfully repopulated StateStore from cache" }
        return 0
      end
      Log.for("quickheadlines.watchdog").warn { "Watchdog: repopulate from cache after atomic recovery failed or returned no data" }
    end

    watchdog_retry_from_cache(config, consecutive)
  end

  private def watchdog_retry_from_cache(config : Config?, consecutive : Int32) : Int32
    attempts = 0
    success = false

    while attempts < QuickHeadlines::Constants::WATCHDOG_MAX_ATTEMPTS
      attempts += 1
      Log.for("quickheadlines.watchdog").info { "Watchdog: load_feeds_from_cache attempt #{attempts}" }
      if config && FeedFetcher.load_feeds_from_cache(config)
        Log.for("quickheadlines.watchdog").info { "Watchdog: load_feeds_from_cache succeeded on attempt #{attempts}" }
        success = true
        break
      end
      RefreshLoop::InterruptibleSleep.sleep(QuickHeadlines::Constants::WATCHDOG_RETRY_INTERVAL_SECONDS)
    end

    if success
      return 0
    end

    Log.for("quickheadlines.watchdog").error { "Watchdog: failed to recover refresh after #{attempts} attempts" }

    if QuickHeadlines::Constants::WATCHDOG_ESCALATE_EXIT
      Log.for("quickheadlines.watchdog").fatal { "Watchdog: exiting process to allow external supervisor to restart" }
      exit 1
    end

    consecutive
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
      begin
        RefreshLoop.start("feeds.yml", @feed_cache, @db_service)
      rescue ex
        Log.for("quickheadlines.app").error(exception: ex) { "start_feed_refresh failed" }
      end
    end
  end

  private def start_clustering_scheduler
    RefreshLoop::FiberTracker.tracked_spawn do
      loop do
        begin
          RefreshLoop::InterruptibleSleep.sleep(@clustering_interval)
          break if QuickHeadlines.shutting_down?
          threshold = StateStore.config.try(&.clustering).try(&.threshold) || 0.35
          QuickHeadlines::Services::ClusteringService.new(@db_service).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Clustering scheduler iteration failed" }
        end
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
          QuickHeadlines::Services::ClusteringService.new(@db_service).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
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
          begin
            memory_status = MemoryManagerActor.instance.get_memory_status
            case memory_status.pressure_level
            when .critical?
              Log.for("quickheadlines.app").warn { "Running emergency cleanup due to critical memory pressure" }
              MemoryManagerActor.instance.request_cleanup(MemoryManagerActor::CleanupPriority::Emergency)
            when .high?
              Log.for("quickheadlines.app").warn { "Running aggressive cleanup due to high memory pressure" }
              MemoryManagerActor.instance.request_cleanup(MemoryManagerActor::CleanupPriority::Aggressive)
            else
              MemoryManagerActor.instance.request_cleanup(MemoryManagerActor::CleanupPriority::Normal)
            end
          rescue ex
            Log.for("quickheadlines.app").debug { "Memory pressure check failed: #{ex.message}" }
            MemoryManagerActor.instance.request_cleanup(MemoryManagerActor::CleanupPriority::Normal)
          end

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
