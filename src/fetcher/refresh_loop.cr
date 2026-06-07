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
  # Public API — entry points for refresh loop
  # -------------------------------------------------------------------------

  # Main refresh function used by the supervisor. Collects the union
  # of `config.feeds` and the feeds inside each tab, runs the
  # concurrent fetch via `FeedFetcherConcurrent`, then rebuilds
  # `new_feeds` and `new_tabs` (with the per-tab software releases)
  # before pushing the result into `StateStore`.
  def self.refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Nil)? = nil) : Nil
    StateStore.update(&.copy_with(config_title: config.page_title, config: config))
    RefreshHealthMonitor.record_cycle_start

    # Inlined from old `collect_feed_configs` — union of top-level
    # feeds and the feeds inside each tab, keyed by URL.
    all_configs = {} of String => Feed
    config.feeds.each { |feed| all_configs[feed.url] = feed }
    config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
    Log.for("quickheadlines.feed").info { "refresh_all: starting - #{all_configs.size} feeds to fetch" }

    existing_data = (StateStore.feeds + StateStore.tabs.flat_map(&.feeds)).index_by(&.url)

    # Inlined from old `cancel_check` — non-blocking check for an
    # already-signaled cancel channel.
    if cancel_ch
      select
      when cancel_ch.receive?
        raise CancelError.new
      when timeout(0.seconds)
      end
    end

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
    # Inlined from old `build_tab_feeds` and `build_software_releases`.
    new_tabs = config.tabs.map do |tab_config|
      tab_feeds = tab_config.feeds.map do |feed|
        FeedFetcherConcurrent.best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
      end
      tab_releases = QuickHeadlines::SoftwareUtil.build_software_releases(tab_config.software_releases, config.item_limit)
      Tab.new(tab_config.name, tab_feeds, tab_releases)
    end

    existing_data = nil

    if cancel_ch
      select
      when cancel_ch.receive?
        raise CancelError.new
      when timeout(0.seconds)
      end
    end

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

  # Start the refresh loop supervisor and the periodic health/memory
  # reporter. The supervisor is the long-lived orchestrator; the
  # reporter is a sibling fiber that wakes every few minutes to log
  # refresh-cycle and memory diagnostics.
  def self.start(config_path : String, cache : FeedCache, db_service : DatabaseService) : Nil
    # Touch the pool accessor so the SemaphorePool is built before any
    # fibers are spawned below. The accessor is idempotent and cheap.
    pool
    RefreshLoop::Supervisor.start(config_path, cache, db_service, RefreshLoop.pool)
    RefreshLoop::HealthReporter.start
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
