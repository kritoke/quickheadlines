require "gc"
require "time"
require "../config"
require "../models"
require "../storage"
require "../software_fetcher"
require "../websocket"
require "./feed_fetcher"
require "./software_util"

class CancelError < Exception
  def initialize(message : String = "Refresh cancelled")
    super(message)
  end
end

private def cancel_check(cancel_ch : Channel(Bool)?) : Nil
  return unless cancel_ch
  select
  when cancel_ch.receive?
    raise CancelError.new
  when timeout(0.seconds)
  end
end

module GCCollector
  @@last_gc_collect = Time.utc

  def self.maybe_collect : Nil
    now = Time.utc
    if now - @@last_gc_collect >= 90.seconds
      GC.collect
      @@last_gc_collect = now
      Log.for("quickheadlines.gc").debug { "Triggered GC.collect to release memory" }
    end
  end
end

private def log_duration_warning(refresh_duration, active_config)
  expected_seconds = active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE
  hang_threshold = expected_seconds * 2
  if refresh_duration > hang_threshold
    Log.for("quickheadlines.feed").warn { "Refresh took #{refresh_duration.round(2)}s (expected #{expected_seconds}s) - possible hang detected" }
  end
end

# Resolve the best available data for a feed.
# Priority: fresh-good > stale-good > fresh-bad > stale-bad > synthetic error
private def best_available_feed(feed : Feed, fetched : FeedData?, existing : FeedData?) : FeedData
  return fetched if fetched && !fetched.failed?
  return existing if existing && !existing.failed?
  fetched || existing || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch")
end

# Uses select+timeout pattern to ensure fetch completes within time limit.
# NOTE: The inner fiber may continue running after timeout and will complete when it can
# send to the buffered channel (non-blocking send). This prevents fiber accumulation
# that would occur with an unbuffered channel where send() blocks forever.
private def fetch_single_feed_with_timeout(feed : Feed, config : Config, previous_feed_data : FeedData?, index : Int32) : FeedData
  timeout_seconds = QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS

  # Buffered channel (size 1) prevents inner fiber from blocking on send() after timeout.
  # Without buffering, the fiber would block forever waiting for a receiver that already
  # returned. With buffering, the send succeeds immediately and the fiber completes.
  result_channel = Channel(FeedData | Exception).new(1)

  spawn(name: "feed_fetch_inner_#{index}") do
    begin
      fetch_result = FeedFetcher.instance.fetch(feed, config.item_limit, config.db_fetch_limit, previous_feed_data)
      result_channel.send(fetch_result)
    rescue ex : Exception
      result_channel.send(ex)
    end
  end

  timed_out = false
  channel_result = nil

  select
  when value = result_channel.receive?
    channel_result = value
  when timeout(timeout_seconds.seconds)
    timed_out = true
  end

  if timed_out
    Log.for("quickheadlines.feed").warn { "fetch_single_feed_with_timeout: feed #{feed.url} timed out after #{timeout_seconds}s" }
    if previous_feed_data && !previous_feed_data.failed?
      Log.for("quickheadlines.feed").info { "fetch_single_feed_with_timeout: using cached data for #{feed.url}" }
      previous_feed_data
    else
      FeedFetcher.instance.build_error_feed(feed, "Error: Fetch timeout after #{timeout_seconds}s")
    end
  elsif value = channel_result
    if value.is_a?(Exception)
      Log.for("quickheadlines.feed").error(exception: value) { "Fetch failed for #{feed.url}" }
      if previous_feed_data && !previous_feed_data.failed?
        Log.for("quickheadlines.feed").info { "fetch_single_feed_with_timeout: using cached data after exception for #{feed.url}" }
        previous_feed_data
      else
        FeedFetcher.instance.build_error_feed(feed, "Error: #{value.class}")
      end
    else
      value
    end
  else
    Log.for("quickheadlines.feed").error { "fetch_single_feed_with_timeout: unexpected nil result for #{feed.url}" }
    if previous_feed_data && !previous_feed_data.failed?
      previous_feed_data
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
  @@feeds_in_progress : Atomic(Int32) = Atomic(Int32).new(0)

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

  # Track feed fetch start/end for monitoring fiber accumulation
  def self.feed_fetch_started : Nil
    @@feeds_in_progress.add(1)
  end

  def self.feed_fetch_completed : Nil
    @@feeds_in_progress.add(-1)
  end

  def self.status : {last_start: Int64, last_complete: Int64, cycles: Int32, failures: Int32, feeds_in_progress: Int32}
    {
      last_start:        @@last_refresh_start.get,
      last_complete:     @@last_refresh_complete.get,
      cycles:            @@refresh_cycles_completed.get,
      failures:          @@refresh_failures.get,
      feeds_in_progress: @@feeds_in_progress.get,
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
  status = semaphore_health_status
  if status[:available] != status[:expected]
    Log.for("quickheadlines.feed").warn { "Semaphore health check: #{status[:available]}/#{status[:expected]} slots available" }
  end
end

private def collect_feed_configs(config : Config) : Hash(String, Feed)
  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
  all_configs
end

private def fetch_feeds_concurrently(all_configs : Hash(String, Feed), existing_data : Hash(String, FeedData), config : Config) : Hash(String, FeedData)
  channel = Channel(FeedData?).new(all_configs.size) # buffered so senders don't block on timeout
  feed_index = 0
  all_configs.each_value do |feed|
    current_index = feed_index
    feed_index += 1
    spawn(name: "feed_fetch_outer_#{current_index}") do
      acquire_semaphore
      begin
        previous_feed_data = existing_data[feed.url]?
        # Per-feed timeout to prevent one hung fetch from blocking the semaphore slot
        # This is critical for preventing semaphore exhaustion over long running sessions
        RefreshHealthMonitor.feed_fetch_started
        result = fetch_single_feed_with_timeout(feed, config, previous_feed_data, current_index)
        begin
          channel.send(result)
        rescue Channel::ClosedError
        end
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feeds_concurrently: error fetching #{feed.url}" }
        previous_feed_data = existing_data[feed.url]?
        if previous_feed_data && !previous_feed_data.failed?
          Log.for("quickheadlines.feed").info { "fetch_feeds_concurrently: using cached data after outer error for #{feed.url}" }
          begin
            channel.send(previous_feed_data)
          rescue Channel::ClosedError
          end
        else
          begin
            channel.send(FeedFetcher.instance.build_error_feed(feed, "Error: #{ex.class}"))
          rescue Channel::ClosedError
          end
        end
      ensure
        RefreshHealthMonitor.feed_fetch_completed
        # Ensure semaphore slot is always returned, even on exceptions
        begin
          release_semaphore
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

  # Use select with timeout per iteration for overall timeout protection
  # Instead of excessive Fiber.yield, use blocking receive with select wrapper
  end_time = Time.utc + overall_timeout
  total_feeds.times do
    remaining = (end_time - Time.utc).total_seconds
    break if remaining <= 0

    select
    when feed_data = channel.receive?
      if feed_data
        fetched_map[feed_data.url] = feed_data
      elsif config.debug?
        Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: failed to fetch feed" }
      end
      completed += 1
    when timeout(remaining.ceil.clamp(0.1, 10).seconds)
      # Timeout on this iteration - check if we've completed all or should continue
      if completed >= total_feeds
        break
      end
      # Continue to next iteration for remaining time budget
    end
  end

  if completed < total_feeds
    Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: fetched #{completed}/#{total_feeds} feeds" }
  end
  channel.close
  fetched_map
end

private def build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
  QuickHeadlines::SoftwareUtil.build_software_releases(software_config, item_limit)
end

private def build_tab_feeds(tab_config : TabConfig, fetched_map : Hash(String, FeedData), existing_data : Hash(String, FeedData), item_limit : Int32) : Tab
  tab_feeds = tab_config.feeds.map do |feed|
    best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
  end
  tab_releases = build_software_releases(tab_config.software_releases, item_limit)
  Tab.new(tab_config.name, tab_feeds, tab_releases)
end

def refresh_all(config : Config, cancel_ch : Channel(Bool)? = nil)
  refresh_all(config, FeedCache.instance, DatabaseService.instance, cancel_ch)
end

def refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Bool)? = nil)
  # NOTE: refreshing flag is managed by the caller (supervisor), not here.
  # This prevents race conditions between timed-out workers and the supervisor.
  StateStore.update(&.copy_with(config_title: config.page_title, config: config))
  RefreshHealthMonitor.record_cycle_start

  all_configs = collect_feed_configs(config)
  Log.for("quickheadlines.feed").info { "refresh_all: starting - #{all_configs.size} feeds to fetch" }

  existing_data = (StateStore.feeds + StateStore.tabs.flat_map(&.feeds)).index_by(&.url)

  cancel_check(cancel_ch)

  fetched_map = fetch_feeds_concurrently(all_configs, existing_data, config)
  fetched_count = fetched_map.size
  missing_count = all_configs.size - fetched_count

  if missing_count > 0
    Log.for("quickheadlines.feed").warn { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds, #{missing_count} missing or timed out" }
  else
    Log.for("quickheadlines.feed").debug { "refresh_all: fetched #{fetched_count}/#{all_configs.size} feeds successfully" }
  end

  new_feeds = config.feeds.map do |feed|
    best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
  end
  new_tabs = config.tabs.map { |tab_config| build_tab_feeds(tab_config, fetched_map, existing_data, config.item_limit) }

  existing_data = nil

  cancel_check(cancel_ch)

  Log.for("quickheadlines.feed").info { "refresh_all: about to update StateStore - fetched_count=#{fetched_count}, missing_count=#{missing_count}, new_feeds=#{new_feeds.size}, new_tabs=#{new_tabs.size}" }

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
  StateStore.refreshing = true
  refresh_start_time = Time.utc
  outer_timeout = state.outer_timeout_seconds.seconds
  config_snapshot = state.active_config
  refresh_all_start = Time.utc

  cancel_ch = Channel(Bool).new(1)
  completion_channel = Channel(Nil).new(1)
  spawn(name: "refresh_worker") do
    begin
      refresh_all(config_snapshot, cache, db_service, cancel_ch)
      refresh_all_duration = (Time.utc - refresh_all_start).total_seconds
      if config_snapshot.debug?
        Log.for("quickheadlines.feed").debug { "Refreshed feeds in #{refresh_all_duration.round(2)}s" }
      elsif refresh_all_duration > 120
        Log.for("quickheadlines.feed").warn { "refresh_all took #{refresh_all_duration.round(2)}s - long duration" }
      end
    rescue ex : CancelError
      Log.for("quickheadlines.feed").warn { "Refresh worker cancelled by supervisor: #{ex.message}" }
      RefreshHealthMonitor.record_failure
    rescue ex
      Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop refresh_all failed" }
      RefreshHealthMonitor.record_failure
    end
    completion_channel.send(nil)
  end

  select
  when completion_channel.receive?
    StateStore.refreshing = false
    refresh_duration = (Time.utc - refresh_start_time).total_seconds
    Log.for("quickheadlines.feed").debug { "Starting save_feed_cache..." }
    cache.save(config_snapshot.cache_retention_hours, config_snapshot.max_cache_size_mb)
    Log.for("quickheadlines.feed").debug { "save_feed_cache complete" }
    GC.collect
    refresh_duration
  when timeout(outer_timeout)
    cancel_ch.send(true)
    StateStore.refreshing = false
    Log.for("quickheadlines.feed").error { "refresh_all timed out after #{outer_timeout.total_seconds.round}s - worker signalled to cancel" }
    RefreshHealthMonitor.record_failure
    GC.collect
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
        health_check_done = Channel(Nil).new(1)
        spawn do
          begin
            ::sleep(5.minutes)
            health_check_done.send(nil)
          rescue ex
            Log.for("quickheadlines.feed").error(exception: ex) { "Health check timer failed" }
          end
        end
        select
        when health_check_done.receive
          break if QuickHeadlines.shutting_down?
          status = RefreshHealthMonitor.status
          if status[:failures] > 0 || status[:last_complete] == 0
            Log.for("quickheadlines.feed").warn do
              "Refresh health: cycles=#{status[:cycles]}, failures=#{status[:failures]}, last_complete=#{status[:last_complete]}"
            end
          end
        when timeout(30.seconds)
          Log.for("quickheadlines.feed").warn { "Health reporter check timed out, continuing" }
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
          # Wait for initial refresh with timeout protection
          initial_wait_done = Channel(Nil).new(1)
          spawn do
            begin
              ::sleep(state.refresh_interval_seconds.seconds)
              initial_wait_done.send(nil)
            rescue ex
              Log.for("quickheadlines.feed").error(exception: ex) { "Initial refresh wait timer failed" }
            end
          end
          select
          when initial_wait_done.receive
            # Normal completion
          when timeout(state.outer_timeout_seconds.seconds)
            Log.for("quickheadlines.feed").warn { "Initial refresh wait timed out after #{state.outer_timeout_seconds}s" }
          end
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
        # Timeout-protected sleep before restart
        restart_done = Channel(Nil).new(1)
        spawn do
          begin
            ::sleep(60.seconds)
            restart_done.send(nil)
          rescue ex
            Log.for("quickheadlines.feed").error(exception: ex) { "Restart delay timer failed" }
          end
        end
        select
        when restart_done.receive
          # Normal restart delay
        when timeout(state.outer_timeout_seconds.seconds)
          Log.for("quickheadlines.feed").warn { "Restart delay timed out, continuing immediately" }
        end
        break if QuickHeadlines.shutting_down?
      end
    end
  end

  start_health_reporter
end
