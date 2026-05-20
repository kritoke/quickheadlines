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

private def log_duration_warning(refresh_duration, active_config)
  threshold = (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE) * 2
  if refresh_duration > threshold
    Log.for("quickheadlines.feed").warn { "Refresh took #{refresh_duration.round(2)}s (expected #{active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE}s) - possible hang detected" }
  end
end

private def trigger_gc_collection : Nil
  GCCollector.trigger_if_needed
end

# Fetch a single feed with hard timeout. Returns FeedData or error feed.
# Uses select+timeout pattern to ensure fetch completes within time limit.
private def fetch_single_feed_with_timeout(feed : Feed, config : Config, prev : FeedData?, index : Int32) : FeedData
  timeout_seconds = QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS

  # Create a channel to receive the result
  result_channel = Channel(FeedData | Exception).new

  # Spawn the actual fetch in a separate fiber
  spawn(name: "feed_fetch_inner_#{index}") do
    begin
      fetch_result = FeedFetcher.instance.fetch(feed, config.item_limit, config.db_fetch_limit, prev)
      result_channel.send(fetch_result)
    rescue ex : Exception
      result_channel.send(ex)
    end
  end

  # Wait for result or timeout
  timed_out = false
  result_value = nil

  select
  when value = result_channel.receive?
    result_value = value
  when timeout(timeout_seconds.seconds)
    timed_out = true
  end

  if timed_out
    Log.for("quickheadlines.feed").warn { "fetch_single_feed_with_timeout: feed #{feed.url} timed out after #{timeout_seconds}s" }
    if prev && !prev.failed?
      Log.for("quickheadlines.feed").info { "fetch_single_feed_with_timeout: using cached data for #{feed.url}" }
      prev
    else
      FeedFetcher.instance.build_error_feed(feed, "Error: Fetch timeout after #{timeout_seconds}s")
    end
  elsif value = result_value
    if value.is_a?(Exception)
      Log.for("quickheadlines.feed").error(exception: value) { "Fetch failed for #{feed.url}" }
      if prev && !prev.failed?
        Log.for("quickheadlines.feed").info { "fetch_single_feed_with_timeout: using cached data after exception for #{feed.url}" }
        prev
      else
        FeedFetcher.instance.build_error_feed(feed, "Error: #{value.class}")
      end
    else
      value
    end
  else
    # This should never happen but handle defensively
    Log.for("quickheadlines.feed").error { "fetch_single_feed_with_timeout: unexpected nil result for #{feed.url}" }
    if prev && !prev.failed?
      prev
    else
      FeedFetcher.instance.build_error_feed(feed, "Error: Unexpected nil result")
    end
  end
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

  # DEV-ONLY: Force a stuck state for testing watchdog (local-only trigger should call this)
  def self.force_stuck!(seconds : Int32 = 600) : Nil
    now_ms = Time.utc.to_unix_ms
    @@last_refresh_start.set(now_ms - (seconds * 1000))
    @@last_refresh_complete.set(0)
    Log.for("quickheadlines.watchdog").info { "RefreshHealthMonitor: forced stuck state for testing (#{seconds}s)" }
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
    Log.for("quickheadlines.feed").warn { "Semaphore health check: only #{available}/#{expected} slots available - refilling #{available}" }
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
  channel = Channel(FeedData?).new(all_configs.size)  # buffered so senders don't block on timeout
  feed_index = 0
  all_configs.each_value do |feed|
    current_index = feed_index
    feed_index += 1
    spawn(name: "feed_fetch_outer_#{current_index}") do
      CONCURRENCY_SEMAPHORE.receive
      begin
        prev = existing_data[feed.url]?
        # Per-feed timeout to prevent one hung fetch from blocking the semaphore slot
        # This is critical for preventing semaphore exhaustion over long running sessions
        result = fetch_single_feed_with_timeout(feed, config, prev, current_index)
        channel.send(result)
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feeds_concurrently: error fetching #{feed.url}" }
        prev = existing_data[feed.url]?
        if prev && !prev.failed?
          Log.for("quickheadlines.feed").info { "fetch_feeds_concurrently: using cached data after outer error for #{feed.url}" }
          channel.send(prev)
        else
          channel.send(FeedFetcher.instance.build_error_feed(feed, "Error: #{ex.class}"))
        end
      ensure
        # Ensure semaphore slot is always returned, even on exceptions
        begin
          CONCURRENCY_SEMAPHORE.send(nil)
        rescue ex
          Log.for("quickheadlines.feed").error(exception: ex) { "Failed to release semaphore for #{feed.url}" }
        end
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
        Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: failed to fetch feed" }
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

private def build_tab_feeds(tab_config : TabConfig, fetched_map : Hash(String, FeedData), existing_data : Hash(String, FeedData), item_limit : Int32) : Tab
  tab_feeds = tab_config.feeds.map do |feed|
    fetched = fetched_map[feed.url]?
    existing = existing_data[feed.url]?
    if fetched && !fetched.failed?
      fetched
    elsif existing && !existing.failed?
      existing
    elsif fetched
      fetched
    elsif existing
      existing
    else
      FeedFetcher.instance.build_error_feed(feed, "Failed to fetch")
    end
  end
  tab_releases = build_software_releases(tab_config.software_releases, item_limit)
  Tab.new(tab_config.name, tab_feeds, tab_releases)
end

def refresh_all(config : Config)
  refresh_all(config, FeedCache.instance, DatabaseService.instance)
end

def refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService)
  # NOTE: refreshing flag is managed by the caller (supervisor), not here.
  # This prevents race conditions between timed-out workers and the supervisor.
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

  # Resolve the best data for a feed: prefer fresh fetch, fall back to previous good data,
  # then to any previous data, and finally to an error feed.
  new_feeds = config.feeds.map do |feed|
    fetched = fetched_map[feed.url]?
    existing = existing_data[feed.url]?
    if fetched && !fetched.failed?
      fetched
    elsif existing && !existing.failed?
      existing
    elsif fetched
      fetched # failed fetch is better than nothing
    elsif existing
      existing # even failed existing data is better than generating new error
    else
      FeedFetcher.instance.build_error_feed(feed, "Failed to fetch")
    end
  end
  new_tabs = config.tabs.map { |tab_config| build_tab_feeds(tab_config, fetched_map, existing_data, config.item_limit) }

  # Diagnostic log: indicate sizes coming into StateStore update
  Log.for("quickheadlines.feed").info { "refresh_all: about to update StateStore - fetched_count=#{fetched_count}, missing_count=#{missing_count}, new_feeds=#{new_feeds.size}, new_tabs=#{new_tabs.size}" }

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
  # NOTE: refreshing flag is managed by the caller, not here.
  raise ex
end

# Mutable state for the refresh loop, scoped to avoid shared variable issues.
private struct RefreshLoopState
  property active_config : Config
  property last_mtime : Time
  property cycle_count : Int32
  property consecutive_skips : Int32
  getter first_run : Bool
  @first_run : Bool = true

  def initialize(@active_config : Config, @last_mtime : Time)
    @cycle_count = 0
    @consecutive_skips = 0
  end

  def mark_first_run_done : Nil
    @first_run = false
  end

  def heartbeat_due?(interval : Int32) : Bool
    @cycle_count > 0 && @cycle_count % interval == 0
  end

  def reset_cycle_count : Nil
    @cycle_count = 0
  end

  def increment_cycle : Nil
    @cycle_count += 1
  end

  def reset_skips : Nil
    @consecutive_skips = 0
  end

  def increment_skips : Int32
    @consecutive_skips += 1
    @consecutive_skips
  end

  def refresh_interval_seconds : Int32
    active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE
  end

  def outer_timeout_seconds : Int32
    refresh_interval_seconds * 3 // 2
  end

  def sleep_timeout_seconds : Int32
    refresh_interval_seconds * 3 // 2
  end

  def stuck_threshold_seconds : Int32
    refresh_interval_seconds * 3
  end

  def heartbeat_interval : Int32
    10
  end

  MAX_CONSECUTIVE_SKIPS = 3
end

# Check if the refresh loop is stuck and attempt recovery.
private def check_stuck_recovery(stuck_threshold : Int32) : Nil
  return unless RefreshHealthMonitor.stuck?(stuck_threshold)

  status = RefreshHealthMonitor.status
  Log.for("quickheadlines.feed").error do
    "REFRESH STUCK: last cycle started at #{status[:last_start]}, " \
    "cycles completed: #{status[:cycles]}, failures: #{status[:failures]}"
  end
  Log.for("quickheadlines.feed").error { "Attempting to recover stuck refresh..." }

  if RefreshHealthMonitor.attempt_recovery
    StateStore.update(&.copy_with(refreshing: false))
    RefreshHealthMonitor.reset_failures
    Log.for("quickheadlines.feed").info { "Recovery complete, will retry on next cycle" }
  else
    Log.for("quickheadlines.feed").info { "Recovery was already performed by another fiber" }
  end
end

# Run the first refresh in a background fiber, then wait for the interval.
private def run_initial_refresh(state : RefreshLoopState, cache : FeedCache, db_service : DatabaseService) : Nil
  if state.active_config.debug?
    Log.for("quickheadlines.feed").debug { "Running initial refresh to fetch feeds" }
  end

  StateStore.refreshing = true
  config_for_initial = state.active_config
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

  if state.active_config.debug?
    Log.for("quickheadlines.feed").debug { "Initial refresh started in background" }
  end
end

# Hot-reload config if the file changed on disk.
private def reload_config_if_changed(config_path : String, state : RefreshLoopState) : Nil
  current_mtime = File.info(config_path).modification_time
  return unless current_mtime > state.last_mtime

  load_result = load_validated_config(config_path)
  if load_result.success && (new_config = load_result.config)
    state.active_config = new_config
    state.last_mtime = current_mtime
    if state.active_config.debug?
      Log.for("quickheadlines.feed").debug { "Config change detected. Reloaded feeds.yml" }
    end
  end
end

# Run a normal refresh cycle with timeout protection.
# Returns the total refresh duration in seconds.
private def run_timed_refresh(state : RefreshLoopState, cache : FeedCache, db_service : DatabaseService) : Float64
  StateStore.refreshing = true # Supervisor owns the flag
  refresh_start_time = Time.utc
  outer_timeout = state.outer_timeout_seconds.seconds
  config_snapshot = state.active_config
  refresh_all_start = Time.utc

  done = Channel(Nil).new(1)
  spawn(name: "refresh_worker") do
    begin
      refresh_all(config_snapshot, cache, db_service)
      refresh_all_duration = (Time.utc - refresh_all_start).total_seconds
      if config_snapshot.debug?
        Log.for("quickheadlines.feed").debug { "Refreshed feeds in #{refresh_all_duration.round(2)}s" }
      elsif refresh_all_duration > 120
        Log.for("quickheadlines.feed").warn { "refresh_all took #{refresh_all_duration.round(2)}s - long duration" }
      end
    rescue ex
      Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop refresh_all failed" }
      RefreshHealthMonitor.record_failure
    end
    done.send(nil)
  end

  select
  when done.receive?
    StateStore.refreshing = false
    refresh_duration = (Time.utc - refresh_start_time).total_seconds
    Log.for("quickheadlines.feed").debug { "Starting save_feed_cache..." }
    cache.save(state.active_config.cache_retention_hours, state.active_config.max_cache_size_mb)
    Log.for("quickheadlines.feed").debug { "save_feed_cache complete" }
    trigger_gc_collection
    refresh_duration
  when timeout(outer_timeout)
    StateStore.refreshing = false # Clear immediately on timeout to prevent stall
    Log.for("quickheadlines.feed").error { "refresh_all timed out after #{outer_timeout.total_seconds.round}s - refreshing flag reset, worker continues in background" }
    RefreshHealthMonitor.record_failure
    (Time.utc - refresh_start_time).total_seconds
  end
end

# Sleep for the configured refresh interval with timeout protection.
private def sleep_between_cycles(state : RefreshLoopState) : Nil
  sleep_duration = state.refresh_interval_seconds.seconds
  outer_sleep_timeout = state.sleep_timeout_seconds.seconds

  sleep_done = Channel(Nil).new(1)
  spawn do
    begin
      sleep sleep_duration
      sleep_done.send(nil)
    rescue ex
      Log.for("quickheadlines.feed").error(exception: ex) { "Sleep timer fiber error" }
    end
  end

  select
  when sleep_done.receive
  when timeout(outer_sleep_timeout)
    Log.for("quickheadlines.feed").error { "refresh loop sleep timed out after #{outer_sleep_timeout.total_seconds.round}s" }
  end
  sleep_done.close unless sleep_done.closed?
end

# Log heartbeat info every N cycles.
private def log_heartbeat(state : RefreshLoopState) : Nil
  return unless state.heartbeat_due?(state.heartbeat_interval)

  status = RefreshHealthMonitor.status
  Log.for("quickheadlines.feed").info do
    "Refresh loop heartbeat: #{state.cycle_count} cycles, " \
    "completed: #{status[:cycles]}, failures: #{status[:failures]}, " \
    "last_start: #{status[:last_start]}, last_complete: #{status[:last_complete]}"
  end
end

# Periodically log health warnings if there are failures.
private def start_health_reporter : Nil
  spawn(name: "health_monitor_reporter") do
    loop do
      begin
        sleep 5.minutes
        break if QuickHeadlines.shutting_down?
        status = RefreshHealthMonitor.status
        if status[:failures] > 0 || status[:last_complete] == 0
          Log.for("quickheadlines.feed").warn do
            "Refresh health: cycles=#{status[:cycles]}, failures=#{status[:failures]}, last_complete=#{status[:last_complete]}"
          end
        end
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "Health monitor reporter error" }
      end
    end
  end
end

# Entry point: starts the refresh loop supervisor fiber and health reporter.
def start_refresh_loop(config_path : String, cache : FeedCache, db_service : DatabaseService)
  load_result = load_validated_config(config_path)
  unless load_result.success && (initial_config = load_result.config)
    Log.for("quickheadlines.feed").error { "Failed to load config: #{load_result.error_message}" }
    return
  end

  state = RefreshLoopState.new(initial_config, File.info(config_path).modification_time)
  cache.save(state.active_config.cache_retention_hours, state.active_config.max_cache_size_mb)

  spawn(name: "refresh_supervisor") do
    loop do
      begin
        break if QuickHeadlines.shutting_down?

        check_stuck_recovery(state.stuck_threshold_seconds)

        if StateStore.refreshing?
          skip_count = state.increment_skips
          if skip_count >= RefreshLoopState::MAX_CONSECUTIVE_SKIPS
            Log.for("quickheadlines.feed").error { "Force-resetting refreshing flag after #{skip_count} consecutive skips - previous refresh may be stuck" }
            StateStore.refreshing = false
            state.reset_skips
            # Fall through to start a fresh refresh instead of sleeping
          else
            Log.for("quickheadlines.feed").warn { "Refresh already in progress, skipping (#{skip_count}/#{RefreshLoopState::MAX_CONSECUTIVE_SKIPS})" }
            sleep state.refresh_interval_seconds.seconds
            break if QuickHeadlines.shutting_down?
            next
          end
        else
          state.reset_skips
        end

        check_semaphore_health

        if state.first_run
          state.mark_first_run_done
          run_initial_refresh(state, cache, db_service)
          sleep state.refresh_interval_seconds.seconds
          break if QuickHeadlines.shutting_down?
          next
        end

        reload_config_if_changed(config_path, state)
        refresh_duration = run_timed_refresh(state, cache, db_service)
        log_duration_warning(refresh_duration, state.active_config)

        sleep_between_cycles(state)
        break if QuickHeadlines.shutting_down?

        state.increment_cycle
        log_heartbeat(state)
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop outer handler: unhandled exception, restarting in 60s" }
        StateStore.refreshing = false
        RefreshHealthMonitor.record_failure
        state.reset_cycle_count
        sleep 60.seconds
        break if QuickHeadlines.shutting_down?
      end
    end
  end

  start_health_reporter
end
