require "gc"
require "time"
require "../config"
require "../models"
require "../storage"
require "../software_fetcher"
require "../websocket"
require "./feed_fetcher"
require "./feed_fetcher_concurrent"
require "./semaphore_pool"
require "./software_util"
require "./refresh_health_monitor"
require "./refresh_health_reporter"
require "./refresh_supervisor"
require "../services/gc_collector"
require "../services/fiber_tracker"
require "../services/memory_manager_actor"

# CancelError is raised when the refresh supervisor signals cancellation
# during a refresh cycle.
class RefreshLoop::CancelError < Exception
  def initialize(message : String = "Refresh cancelled")
    super(message)
  end
end

# The RefreshLoop module encapsulates all refresh cycle logic.
#
# Private top-level functions at the bottom of this file delegate to
# RefreshLoop methods, preserving the existing public API.
module RefreshLoop
  # -------------------------------------------------------------------------
  # Semaphore management
  # -------------------------------------------------------------------------

  # NOTE: The concurrency primitives (channel, atomic counter, repair
  # mutex) now live in `RefreshLoop::SemaphorePool` (see
  # `src/fetcher/semaphore_pool.cr`). A single process-wide instance is
  # created lazily on first use; tests that need to isolate state
  # should call `RefreshLoop.pool.reset_for_testing` between cases.
  @@pool : SemaphorePool?
  @@pool_mutex = Mutex.new(:unchecked)

  def self.pool : SemaphorePool
    @@pool_mutex.synchronize do
      @@pool ||= SemaphorePool.new
    end
  end

  # -------------------------------------------------------------------------
  # Helpers
  # -------------------------------------------------------------------------

  private def self.cancel_check(cancel_ch : Channel(Nil)?) : Nil
    return unless cancel_ch
    select
    when cancel_ch.receive?
      raise CancelError.new
    when timeout(0.seconds)
    end
  end

  private def self.build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
    QuickHeadlines::SoftwareUtil.build_software_releases(software_config, item_limit)
  end

  private def self.build_tab_feeds(
    tab_config : TabConfig,
    fetched_map : Hash(String, FeedData),
    existing_data : Hash(String, FeedData),
    item_limit : Int32,
  ) : Tab
    tab_feeds = tab_config.feeds.map do |feed|
      FeedFetcherConcurrent.best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
    end
    tab_releases = build_software_releases(tab_config.software_releases, item_limit)
    Tab.new(tab_config.name, tab_feeds, tab_releases)
  end

  # -------------------------------------------------------------------------
  # Config collection
  # -------------------------------------------------------------------------

  private def self.collect_feed_configs(config : Config) : Hash(String, Feed)
    all_configs = {} of String => Feed
    config.feeds.each { |feed| all_configs[feed.url] = feed }
    config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
    all_configs
  end

  # -------------------------------------------------------------------------
  # Public API — entry points for refresh loop
  # -------------------------------------------------------------------------

  # Main refresh function used by the supervisor.
  def self.refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Nil)? = nil) : Nil
    StateStore.update(&.copy_with(config_title: config.page_title, config: config))
    RefreshHealthMonitor.record_cycle_start

    all_configs = collect_feed_configs(config)
    Log.for("quickheadlines.feed").info { "refresh_all: starting - #{all_configs.size} feeds to fetch" }

    existing_data = (StateStore.feeds + StateStore.tabs.flat_map(&.feeds)).index_by(&.url)

    cancel_check(cancel_ch)

    fetched_map = FeedFetcherConcurrent.fetch_all(all_configs, existing_data, config, RefreshLoop.pool)
    fetched_count = fetched_map.size
    missing_count = all_configs.size - fetched_count

    if missing_count > 0
      Log.for("quickheadlines.feed").warn { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds, #{missing_count} missing or timed out" }
    else
      Log.for("quickheadlines.feed").debug { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds successfully" }
    end

    new_feeds = config.feeds.map do |feed|
      FeedFetcherConcurrent.best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
    end
    new_tabs = config.tabs.map { |tab_config| build_tab_feeds(tab_config, fetched_map, existing_data, config.item_limit) }

    existing_data = nil

    cancel_check(cancel_ch)

    Log.for("quickheadlines.feed").info do
      "refresh_all: about to update StateStore - fetched_count=#{fetched_count}, missing_count=#{missing_count}, new_feeds=#{new_feeds.size}, new_tabs=#{new_tabs.size}"
    end

    StateStore.update do |state|
      state.copy_with(
        feeds: new_feeds,
        tabs: new_tabs,
        updated_at: Time.utc,
        refreshing: false
      )
    end

    fetched_map = nil

    EventBroadcaster.notify_feed_update(StateStore.updated_at.to_unix_ms)
    RefreshHealthMonitor.record_cycle_complete

    GCCollector.collect_now

    if config.debug?
      Log.for("quickheadlines.feed").debug { "refresh_all: complete - StateStore.feeds=#{new_feeds.size}, StateStore.tabs=#{new_tabs.size}" }
    end
  rescue ex : Exception
    RefreshHealthMonitor.record_failure
    RefreshHealthMonitor.record_cycle_complete
    raise ex
  end

  # Start the refresh loop supervisor.
  def self.start(config_path : String, cache : FeedCache, db_service : DatabaseService) : Nil
    # Touch the pool accessor so the SemaphorePool is built before any
    # fibers are spawned below. The accessor is idempotent and cheap.
    pool
    RefreshLoop::Supervisor.start(config_path, cache, db_service, RefreshLoop.pool)
    start_health_reporter
  end

  # -------------------------------------------------------------------------
  # Health reporter
  # -------------------------------------------------------------------------

  # Periodic health and memory reporter. Spawns a long-lived fiber
  # that wakes every 5 minutes and logs refresh-cycle health plus
  # memory status with diagnostic counts (sockets, event clients,
  # fibers). Kept inline here for now; extraction to
  # `refresh_health_reporter.cr` is a separate concern (ticket
  # `quickhea-az6.3`).
  private def self.start_health_reporter : Nil
    spawn(name: "health_monitor_reporter") do
      loop do
        begin
          break if QuickHeadlines.shutting_down?

          # Sleep in 30-second chunks for responsive shutdown.
          elapsed = Time::Span.zero
          while elapsed < 5.minutes && !QuickHeadlines.shutting_down?
            step = {30.seconds, 5.minutes - elapsed}.min
            select
            when timeout(step)
              elapsed += step
            end
          end

          break if QuickHeadlines.shutting_down?
          status = RefreshHealthMonitor.status
          if status[:failures] > 0 || status[:last_complete] == 0
            Log.for("quickheadlines.feed").warn do
              "Refresh health: cycles=#{status[:cycles]}, failures=#{status[:failures]}, last_complete=#{status[:last_complete]}"
            end
          end

          # Log memory status with diagnostics
          begin
            memory_status = MemoryManagerActor.instance.get_memory_status

            socket_count = begin
              SocketManager.instance.connection_count
            rescue ex : Exception
              Log.for("quickheadlines.memory").debug(exception: ex) { "socket_count unavailable" }
              0
            end
            event_clients = begin
              EventBroadcaster.client_count
            rescue ex : Exception
              Log.for("quickheadlines.memory").debug(exception: ex) { "event_clients unavailable" }
              0
            end
            fiber_stats = FiberTracker.stats

            Log.for("quickheadlines.memory").info do
              "Memory status: RSS=#{memory_status.rss_mb.round(1)}MB, " \
              "pressure=#{memory_status.pressure_level}, GC count=#{memory_status.gc_count}, " \
              "sockets=#{socket_count}, event_clients=#{event_clients}, fibers=#{fiber_stats}"
            end
          rescue ex : Exception
            Log.for("quickheadlines.memory").debug { "Failed to get memory status: #{ex.message}" }
          end
        rescue ex : Exception
          Log.for("quickheadlines.feed").error(exception: ex) { "Health monitor reporter error" }
        end
      end
    end
  end
end

# Expose RefreshHealthMonitor at top level for existing callers (e.g., admin_controller, api_base_controller).
# The module is now nested inside RefreshLoop but we re-export it for API compatibility.
alias RefreshHealthMonitor = RefreshLoop::RefreshHealthMonitor

# Public API — backward-compatible top-level entry points that delegate to
# RefreshLoop module. This preserves the existing require/use surface without
# requiring callers to change.

# Convenience: refresh_all with default services
def refresh_all(config : Config, cancel_ch : Channel(Nil)? = nil)
  RefreshLoop.refresh_all(config, FeedCache.instance, DatabaseService.instance, cancel_ch)
end

# Full refresh_all with injected services
def refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Nil)? = nil)
  RefreshLoop.refresh_all(config, cache, db_service, cancel_ch)
end

# Start the refresh loop
def start_refresh_loop(config_path : String, cache : FeedCache, db_service : DatabaseService)
  RefreshLoop.start(config_path, cache, db_service)
end
