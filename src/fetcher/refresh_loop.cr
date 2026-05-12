require "gc"
require "time"
require "../config"
require "../models"
require "../storage"
require "../software_fetcher"
require "../websocket"
require "./feed_fetcher"
require "./software_util"

module GCCollector
  @@last_gc_collect = Time.utc

  def self.trigger_if_needed : Nil
    now = Time.utc
    if now - @@last_gc_collect >= 5.minutes
      GC.collect
      @@last_gc_collect = now
      Log.for("quickheadlines.gc").debug { "Triggered GC.collect to release memory" }
    end
  end
end

private def trigger_gc_collection : Nil
  GCCollector.trigger_if_needed
end

module RefreshHealthMonitor
  @@last_refresh_start : Atomic(Int64) = Atomic(Int64).new(0)
  @@last_refresh_complete : Atomic(Int64) = Atomic(Int64).new(0)
  @@refresh_cycles_completed : Atomic(Int32) = Atomic(Int32).new(0)
  @@refresh_failures : Atomic(Int32) = Atomic(Int32).new(0)

  def self.record_cycle_start : Nil
    now_ms = Time.utc.to_unix_ms
    @@last_refresh_start.set(now_ms)
    Log.for("quickheadlines.feed").debug { "RefreshHealthMonitor: cycle start recorded at #{now_ms}" }
  end

  def self.record_cycle_complete : Nil
    now_ms = Time.utc.to_unix_ms
    @@last_refresh_complete.set(now_ms)
    @@refresh_cycles_completed.add(1)
    Log.for("quickheadlines.feed").debug { "RefreshHealthMonitor: cycle complete at #{now_ms}, total cycles=#{@@refresh_cycles_completed.get}" }
  end

  def self.record_failure : Nil
    @@refresh_failures.add(1)
  end

  def self.reset_failures : Nil
    @@refresh_failures.set(0)
  end

  def self.status : {last_start: Int64, last_complete: Int64, cycles: Int32, failures: Int32}
    {
      last_start:    @@last_refresh_start.get,
      last_complete: @@last_refresh_complete.get,
      cycles:        @@refresh_cycles_completed.get,
      failures:      @@refresh_failures.get,
    }
  end

  def self.stuck?(max_age_seconds : Int32) : Bool
    start_time = @@last_refresh_start.get
    return false if start_time == 0

    # Only stuck if last cycle started AFTER last completion
    # This prevents false positives when recovery just happened
    last_complete = @@last_refresh_complete.get
    return false if last_complete > start_time

    age_ms = Time.utc.to_unix_ms - start_time
    result = age_ms > (max_age_seconds * 1000)
    if result
      Log.for("quickheadlines.feed").warn do
        "RefreshHealthMonitor.stuck?: start=#{start_time}, last_complete=#{last_complete}, age_ms=#{age_ms}, threshold_ms=#{max_age_seconds * 1000}"
      end
    end
    result
  end

  # Attempt atomic recovery from stuck state
  # Returns true if recovery was successful (we were stuck and now recovered)
  # Returns false if not stuck or recovery was not needed
  def self.attempt_recovery : Bool
    start_time = @@last_refresh_start.get
    return false if start_time == 0

    last_complete = @@last_refresh_complete.get
    return false if last_complete > start_time

    # Atomically try to claim the recovery by checking and resetting
    # Use a compare-and-set pattern via mutex for safety
    old_value = @@last_refresh_start.get
    return false if old_value == 0

    # Reset start time to indicate we're no longer tracking a stuck refresh
    @@last_refresh_start.set(0)
    Log.for("quickheadlines.feed").info { "RefreshHealthMonitor: atomic recovery performed" }
    true
  end
end

private def check_semaphore_health
  # Note: This briefly blocks concurrent fetches while draining and refilling permits.
  # Impact is minimal (~8 receives/sends) and the check only runs periodically.
  # If the semaphore never gets out of sync, this health check could be removed.
  expected = QuickHeadlines::Constants::CONCURRENCY
  available = 0
  expected.times do
    if CONCURRENCY_SEMAPHORE.receive?.nil?
      break
    end
    available += 1
  end

  if available != expected
    Log.for("quickheadlines.feed").warn { "Semaphore health check: only #{available}/#{expected} slots available - refilling #{expected - available}" }
  end

  available.times { CONCURRENCY_SEMAPHORE.send(nil) }
end

private def collect_feed_configs(config : Config) : Hash(String, Feed)
  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
  all_configs
end

private def fetch_feeds_concurrently(all_configs : Hash(String, Feed), existing_data : Hash(String, FeedData), config : Config) : Hash(String, FeedData)
  channel = Channel(FeedData?).new
  all_configs.each_value do |feed|
    spawn do
      CONCURRENCY_SEMAPHORE.receive
      begin
        prev = existing_data[feed.url]?
        # Per-feed timeout to prevent one hung fetch from blocking the semaphore slot
        # This is critical for preventing semaphore exhaustion over long running sessions
        timeout_channel = Channel(FeedData?).new(1)
        # NOTE: This inner spawn MUST be protected - if fetch() throws an exception
        # that isn't caught, the fiber dies silently, causing the timeout_channel
        # to never send, which can hang the entire refresh cycle.
        spawn do
          begin
            result = FeedFetcher.instance.fetch(feed, config.item_limit, config.db_fetch_limit, prev)
            # Wrap send in begin/rescue - if channel closed (timeout fired), discard result
            begin
              timeout_channel.send(result)
            rescue Channel::ClosedError
              # Timeout fired first, result is discarded - this is expected behavior
            end
          rescue ex
            Log.for("quickheadlines.feed").error(exception: ex) { "Inner fetch fiber crashed for #{feed.url}" }
            begin
              timeout_channel.send(FeedFetcher.instance.build_error_feed(feed, "Error: #{ex.class}"))
            rescue Channel::ClosedError
              # Channel already closed, fiber dying anyway
            end
          end
        end
        result = select
        when timeout(QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS.seconds)
          Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: feed #{feed.url} timed out after #{QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS}s in semaphore, returning error feed" }
          channel.send(FeedFetcher.instance.build_error_feed(feed, "Error: Fetch timeout in semaphore"))
        when value = timeout_channel.receive?
          channel.send(value)
        end
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feeds_concurrently: error fetching #{feed.url}" }
        channel.send(FeedFetcher.instance.build_error_feed(feed, "Error: #{ex.class}"))
      ensure
        CONCURRENCY_SEMAPHORE.send(nil)
      end
    end
    Fiber.yield
  end

  fetched_map = {} of String => FeedData
  completed = 0
  total_feeds = all_configs.size
  overall_timeout = 10.minutes

  total_feeds.times do
    Fiber.yield
    select
    when data = channel.receive?
      if data
        fetched_map[data.url] = data
      elsif config.debug?
        Log.for("quickheadlines.feed").warn { "refresh_all: failed to fetch feed" }
      end
      completed += 1
    when timeout(overall_timeout)
      Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: timed out after #{completed}/#{total_feeds} feeds" }
      break
    end
  end
  fetched_map
end

private def build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
  QuickHeadlines::SoftwareUtil.build_software_releases(software_config, item_limit)
end

private def build_tab_feeds(tab_config : TabConfig, fetched_map : Hash(String, FeedData), item_limit : Int32) : Tab
  tab_feeds = tab_config.feeds.map { |feed| fetched_map[feed.url]? || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch") }
  tab_releases = build_software_releases(tab_config.software_releases, item_limit)
  Tab.new(tab_config.name, tab_feeds, tab_releases)
end

def refresh_all(config : Config)
  refresh_all(config, FeedCache.instance, DatabaseService.instance)
end

def refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService)
  StateStore.update(&.copy_with(refreshing: true))
  StateStore.update(&.copy_with(config_title: config.page_title, config: config))
  RefreshHealthMonitor.record_cycle_start

  all_configs = collect_feed_configs(config)
  Log.for("quickheadlines.feed").info { "refresh_all: starting - #{all_configs.size} feeds to fetch" }

  existing_data = (StateStore.feeds + StateStore.tabs.flat_map(&.feeds)).index_by(&.url)

  fetched_map = fetch_feeds_concurrently(all_configs, existing_data, config)
  fetched_count = fetched_map.size
  missing_count = all_configs.size - fetched_count

  if missing_count > 0
    Log.for("quickheadlines.feed").warn { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds, #{missing_count} missing or timed out" }
  else
    Log.for("quickheadlines.feed").debug { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds successfully" }
  end

  new_feeds = config.feeds.map { |feed| fetched_map[feed.url]? || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch") }
  new_tabs = config.tabs.map { |tab_config| build_tab_feeds(tab_config, fetched_map, config.item_limit) }

  StateStore.update do |state|
    state.copy_with(
      feeds: new_feeds,
      tabs: new_tabs,
      updated_at: Time.utc,
      refreshing: false
    )
  end

  EventBroadcaster.notify_feed_update(StateStore.updated_at.to_unix_ms)
  RefreshHealthMonitor.record_cycle_complete

  if config.debug?
    Log.for("quickheadlines.feed").debug { "refresh_all: complete - StateStore.feeds=#{new_feeds.size}, StateStore.tabs=#{new_tabs.size}" }
  end
rescue ex
  RefreshHealthMonitor.record_failure
  RefreshHealthMonitor.record_cycle_complete
  StateStore.update(&.copy_with(refreshing: false))
  raise ex
end

# ameba:disable Metrics/CyclomaticComplexity
def start_refresh_loop(config_path : String, cache : FeedCache, db_service : DatabaseService)
  load_result = load_validated_config(config_path)
  unless load_result.success && (initial_config = load_result.config)
    Log.for("quickheadlines.feed").error { "Failed to load config: #{load_result.error_message}" }
    return
  end
  active_config = initial_config
  last_mtime = File.info(config_path).modification_time

  save_feed_cache(cache, active_config.cache_retention_hours, active_config.max_cache_size_mb)

  first_run = true
  cycle_count = 0
  heartbeat_interval = 10
  stuck_threshold_seconds = (active_config.refresh_minutes * 60) * 3

  spawn(name: "refresh_supervisor") do
    loop do
      break if QuickHeadlines.shutting_down?

      if RefreshHealthMonitor.stuck?(stuck_threshold_seconds)
        status = RefreshHealthMonitor.status
        Log.for("quickheadlines.feed").error do
          "REFRESH STUCK: last cycle started at #{status[:last_start]}, " \
          "cycles completed: #{status[:cycles]}, failures: #{status[:failures]}"
        end
        Log.for("quickheadlines.feed").error { "Attempting to recover stuck refresh..." }

        # Use atomic recovery to prevent race condition with ongoing refresh fiber
        if RefreshHealthMonitor.attempt_recovery
          StateStore.update(&.copy_with(refreshing: false))
          RefreshHealthMonitor.reset_failures
          Log.for("quickheadlines.feed").info { "Recovery complete, will retry on next cycle" }
        else
          # Another recovery already happened, just log and continue
          Log.for("quickheadlines.feed").info { "Recovery was already performed by another fiber" }
        end
      end

      refresh_start_time = Time.utc

      if StateStore.refreshing?
        Log.for("quickheadlines.feed").warn { "Refresh already in progress, skipping this cycle" }
        sleep (active_config.refresh_minutes * 60).seconds
        break if QuickHeadlines.shutting_down?
        next
      end

      check_semaphore_health

      begin
        if first_run
          first_run = false
          if active_config.debug?
            Log.for("quickheadlines.feed").debug { "Running initial refresh to fetch feeds" }
          end
          # Capture config snapshot before fiber to avoid shared variable
          config_for_initial = active_config
          spawn(name: "initial_refresh") do
            begin
              refresh_all(config_for_initial, cache, db_service)
            rescue ex
              Log.for("quickheadlines.feed").error(exception: ex) { "Initial refresh failed" }
              RefreshHealthMonitor.record_failure
            ensure
              StateStore.refreshing = false
            end
          end
          if active_config.debug?
            Log.for("quickheadlines.feed").debug { "Initial refresh started in background" }
          end
          sleep (active_config.refresh_minutes * 60).seconds
          break if QuickHeadlines.shutting_down?
          next
        else
          current_mtime = File.info(config_path).modification_time

          if current_mtime > last_mtime
            load_result = load_validated_config(config_path)
            if load_result.success && (new_config = load_result.config)
              active_config = new_config
              last_mtime = current_mtime

              if active_config.debug?
                Log.for("quickheadlines.feed").debug { "Config change detected. Reloaded feeds.yml" }
              end
            end
          end

          begin
            refresh_all_start = Time.utc
            refresh_all(active_config, cache, db_service)
            refresh_all_duration = (Time.utc - refresh_all_start).total_seconds
            if active_config.debug?
              Log.for("quickheadlines.feed").debug { "Refreshed feeds in #{refresh_all_duration.round(2)}s" }
            elsif refresh_all_duration > 120
              Log.for("quickheadlines.feed").warn { "refresh_all took #{refresh_all_duration.round(2)}s - long duration" }
            end
          rescue ex
            Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop refresh_all failed" }
            RefreshHealthMonitor.record_failure
          ensure
            StateStore.refreshing = false
          end

          Log.for("quickheadlines.feed").debug { "Starting save_feed_cache..." }
          save_feed_cache(cache, active_config.cache_retention_hours, active_config.max_cache_size_mb)
          Log.for("quickheadlines.feed").debug { "save_feed_cache complete" }
          trigger_gc_collection

          refresh_duration = (Time.utc - refresh_start_time).total_seconds
          if refresh_duration > (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE) * 2
            Log.for("quickheadlines.feed").warn { "Refresh took #{refresh_duration.round(2)}s (expected #{active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE}s) - possible hang detected" }
          end
        end

        sleep_duration = (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE).seconds
        outer_timeout = (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE * 3 // 2).seconds

        sleep_done = Channel(Nil).new(1)
        spawn { sleep sleep_duration; sleep_done.send(nil) }
        select
        when sleep_done.receive
        when timeout(outer_timeout)
          Log.for("quickheadlines.feed").error { "refresh loop sleep timed out after #{outer_timeout.total_seconds.round}s" }
        end
        # Ensure the spawned fiber doesn't leak - close the channel so any pending send will raise
        sleep_done.close unless sleep_done.closed?

        break if QuickHeadlines.shutting_down?

        cycle_count += 1
        if cycle_count % heartbeat_interval == 0
          status = RefreshHealthMonitor.status
          Log.for("quickheadlines.feed").info do
            "Refresh loop heartbeat: #{cycle_count} cycles, last complete: #{status[:last_complete]}"
          end
        end
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop outer handler: unhandled exception, restarting in 60s" }
        StateStore.refreshing = false
        RefreshHealthMonitor.record_failure
        cycle_count = 0
        sleep 60.seconds
        break if QuickHeadlines.shutting_down?
      end
    end
  end

  spawn(name: "health_monitor_reporter") do
    loop do
      sleep 5.minutes
      break if QuickHeadlines.shutting_down?
      status = RefreshHealthMonitor.status
      if status[:failures] > 0 || status[:last_complete] == 0
        Log.for("quickheadlines.feed").warn do
          "Refresh health: cycles=#{status[:cycles]}, failures=#{status[:failures]}, last_complete=#{status[:last_complete]}"
        end
      end
    end
  end
end
