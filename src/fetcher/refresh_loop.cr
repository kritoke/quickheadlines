require "gc"
require "time"
require "../config"
require "../models"
require "../storage"
require "../software_fetcher"
require "../websocket"
require "./feed_fetcher"
require "./software_util"
require "../services/memory_monitor_actor"
require "../services/memory_budget_actor"
require "../services/cleanup_coordinator_actor"

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

  # NOTE: These are module-level constants that hold mutable state (Channel and
  # Atomic). This is intentional — the refresh loop is a process-global singleton
  # that starts once and runs for the lifetime of the process. There is no
  # module-level teardown, so the Channel and Atomic can live at module scope
  # rather than as instance variables on a class.
  #
  # Trade-off: if RefreshLoop.start is called in a test context, the same
  # semaphore is shared across all test cases. Call .reset_semaphore after each
  # test to clean state. This is acceptable since there are no existing specs
  # for the semaphore — it's tested only via integration tests.
  CONCURRENCY_LIMIT     = 8
  CONCURRENCY_SEMAPHORE = Channel(Nil).new(CONCURRENCY_LIMIT)
  CONCURRENCY_AVAILABLE = Atomic(Int32).new(CONCURRENCY_LIMIT)
  # Mutex to make repair read-modify-write atomic (see check_semaphore_health)
  @@repair_mutex = Mutex.new(:unchecked)

  CONCURRENCY_LIMIT.times { CONCURRENCY_SEMAPHORE.send(nil) }

  private def self.acquire_semaphore : Nil
    CONCURRENCY_SEMAPHORE.receive
    CONCURRENCY_AVAILABLE.add(-1, :relaxed)
  end

  private def self.release_semaphore : Nil
    CONCURRENCY_AVAILABLE.add(1, :relaxed)
    CONCURRENCY_SEMAPHORE.send(nil)
  rescue Channel::ClosedError
  end

  def self.semaphore_health_status : {available: Int32, expected: Int32}
    available = CONCURRENCY_AVAILABLE.get
    {available: available, expected: CONCURRENCY_LIMIT}
  end

  # Reset the semaphore to full capacity — use in tests to isolate test cases.
  # Clears and re-fills the channel, resets the atomic counter.
  def self.reset_semaphore : Nil
    while CONCURRENCY_AVAILABLE.get < CONCURRENCY_LIMIT
      CONCURRENCY_AVAILABLE.add(1, :relaxed)
      CONCURRENCY_SEMAPHORE.send(nil)
    end
  end

  # -------------------------------------------------------------------------
  # Helpers
  # -------------------------------------------------------------------------

  private def self.cancel_check(cancel_ch : Channel(Bool)?) : Nil
    return unless cancel_ch
    select
    when cancel_ch.receive?
      raise CancelError.new
    when timeout(0.seconds)
    end
  end

  private def self.log_duration_warning(refresh_duration, active_config)
    expected_seconds = active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE
    hang_threshold = expected_seconds * 2
    if refresh_duration > hang_threshold
      Log.for("quickheadlines.feed").warn { "Refresh took #{refresh_duration.round(2)}s (expected #{expected_seconds}s) - possible hang detected" }
    end
  end

  # Resolve the best available data for a feed.
  # Priority: fresh-good > stale-good > fresh-bad > stale-bad > synthetic error
  private def self.best_available_feed(feed : Feed, fetched : FeedData?, existing : FeedData?) : FeedData
    return fetched if fetched && !fetched.failed?
    return existing if existing && !existing.failed?
    fetched || existing || FeedFetcher.instance.build_error_feed(feed, "Failed to fetch")
  end

  # Returns previous FeedData if it exists and is not a failed feed,
  # otherwise builds a synthetic error feed. Used by all per-feed
  # fallback paths (timeout, exception, nil result, outer error) so the
  # "use cached, else build error" policy lives in exactly one place.
  private def self.fallback_feed(feed : Feed, previous : FeedData?, error_message : String, context : String) : FeedData
    if previous && !previous.failed?
      Log.for("quickheadlines.feed").info { "#{context}: using cached data for #{feed.url}" }
      previous
    else
      FeedFetcher.instance.build_error_feed(feed, error_message)
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
      best_available_feed(feed, fetched_map[feed.url]?, existing_data[feed.url]?)
    end
    tab_releases = build_software_releases(tab_config.software_releases, item_limit)
    Tab.new(tab_config.name, tab_feeds, tab_releases)
  end

  # -------------------------------------------------------------------------
  # Feed fetching
  # -------------------------------------------------------------------------

  private def self.fetch_single_feed_in_background(
    feed : Feed,
    config : Config,
    previous_feed_data : FeedData?,
    channel : Channel(FeedData?),
    index : Int32,
  ) : Nil
    acquire_semaphore
    begin
      RefreshHealthMonitor.feed_fetch_started
      result = fetch_single_feed_with_timeout(feed, config, previous_feed_data, index)
      begin
        channel.send(result)
      rescue Channel::ClosedError
      end
    rescue ex : CancelError
      # Re-raise so the supervisor's CancelError rescue fires and the
      # cancellation is logged distinctly from a fetch error. `ensure` still
      # runs, releasing the semaphore and decrementing the in-progress count.
      # This is defense-in-depth: today CancelError is only raised in
      # refresh_all's cancel_check, but if cancel_check is ever pushed deeper
      # (e.g. into the per-feed fetch path), this prevents it from being
      # silently converted into a fallback FeedData.
      raise ex
    rescue ex : Exception
      Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feeds_concurrently: error fetching #{feed.url}" }
      fallback = fallback_feed(feed, previous_feed_data, "Error: #{ex.class}", "fetch_feeds_concurrently: using cached data after outer error")
      begin
        channel.send(fallback)
      rescue Channel::ClosedError
      end
    ensure
      RefreshHealthMonitor.feed_fetch_completed
      release_semaphore
    end
  end

  private def self.fetch_single_feed_with_timeout(
    feed : Feed,
    config : Config,
    previous_feed_data : FeedData?,
    index : Int32,
  ) : FeedData
    timeout_seconds = QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS

    # Buffered channel (size 1) prevents inner fiber from blocking on send()
    # after timeout. Without buffering, the fiber would block forever waiting
    # for a receiver that already returned.
    result_channel = Channel(FeedData | Exception).new(1)

    spawn(name: "feed_fetch_inner_#{index}") do
      begin
        fetch_result = FeedFetcher.instance.fetch(feed, config.item_limit, config.db_fetch_limit, previous_feed_data)
        result_channel.send(fetch_result)
      rescue ex : Exception
        begin
          result_channel.send(ex)
        rescue Channel::ClosedError
          # Channel closed by timeout — inner fiber can exit
        end
      end
    end

    timed_out = false
    channel_result = nil

    select
    when value = result_channel.receive?
      channel_result = value
    when timeout(timeout_seconds.seconds)
      timed_out = true
      result_channel.close
    end

    if timed_out
      Log.for("quickheadlines.feed").warn { "fetch_single_feed_with_timeout: feed #{feed.url} timed out after #{timeout_seconds}s" }
      fallback_feed(feed, previous_feed_data, "Error: Fetch timeout after #{timeout_seconds}s", "fetch_single_feed_with_timeout")
    elsif value = channel_result
      if value.is_a?(Exception)
        Log.for("quickheadlines.feed").error(exception: value) { "Fetch failed for #{feed.url}" }
        fallback_feed(feed, previous_feed_data, "Error: #{value.class}", "fetch_single_feed_with_timeout: using cached data after exception")
      else
        value
      end
    else
      Log.for("quickheadlines.feed").error { "fetch_single_feed_with_timeout: unexpected nil result for #{feed.url}" }
      fallback_feed(feed, previous_feed_data, "Error: Unexpected nil result", "fetch_single_feed_with_timeout: nil result")
    end
  end

  private def self.fetch_feeds_concurrently(
    all_configs : Hash(String, Feed),
    existing_data : Hash(String, FeedData),
    config : Config,
  ) : Hash(String, FeedData)
    channel = Channel(FeedData?).new(all_configs.size)
    feed_index = 0
    all_configs.each_value do |feed|
      current_index = feed_index
      feed_index += 1
      previous_feed_data = existing_data[feed.url]?
      spawn(name: "feed_fetch_outer_#{current_index}") do
        fetch_single_feed_in_background(feed, config, previous_feed_data, channel, current_index)
      end
      Fiber.yield
    end

    fetched_map = {} of String => FeedData
    completed = 0
    total_feeds = all_configs.size
    overall_timeout = 10.minutes

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
        if completed >= total_feeds
          break
        end
      end
    end

    if completed < total_feeds
      Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: fetched #{completed}/#{total_feeds} feeds" }
    end
    channel.close
    fetched_map
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
  # GC management
  # -------------------------------------------------------------------------

  module GCCollector
    @@last_gc_collect = Time.utc
    @@last_full_collection = Time.utc
    @@gc_runs : Int32 = 0

    def self.maybe_collect : Nil
      now = Time.utc
      if now - @@last_gc_collect >= 5.minutes
        GC.collect
        @@last_gc_collect = now
        @@gc_runs += 1
        Log.for("quickheadlines.gc").debug { "Triggered GC.collect (run #{@@gc_runs})" }

        # Every 2 hours, run full collection to reclaim memory
        if now - @@last_full_collection >= 2.hours
          Log.for("quickheadlines.gc").info { "Running GC.full collection to defragment memory" }
          GC.collect
          GC.collect # Second pass for deeper cleanup
          @@last_full_collection = now
          Log.for("quickheadlines.gc").info { "GC.full collection complete" }
        end
      end
    end

    def self.collect_now : Nil
      GC.collect
      @@last_gc_collect = Time.utc
      @@gc_runs += 1
      Log.for("quickheadlines.gc").debug { "Forced GC.collect after refresh cycle (run #{@@gc_runs})" }

      # Force full collection every 50 cycles
      if @@gc_runs % 50 == 0
        Log.for("quickheadlines.gc").info { "Running periodic GC.full collection (every 50 cycles)" }
        GC.collect
        GC.collect # Second pass
        @@last_full_collection = Time.utc
      end
    end

    def self.stats : String
      "gc_runs=#{@@gc_runs}, last_collect=#{@@last_gc_collect}, last_full_collection=#{@@last_full_collection}"
    end
  end

  # -------------------------------------------------------------------------
  # Fiber tracking (for leak diagnosis)
  # -------------------------------------------------------------------------

  module FiberTracker
    @@active_fibers = Atomic(Int32).new(0)
    @@peak_fibers = Atomic(Int32).new(0)
    @@fiber_spawns = Atomic(Int32).new(0)

    # Call this when spawning a fiber
    def self.track_spawn : Nil
      count = @@active_fibers.add(1)
      @@fiber_spawns.add(1)
      # Update peak
      current_peak = @@peak_fibers.get
      @@peak_fibers.add(1) if count > current_peak
    end

    # Call this when a fiber exits
    def self.track_exit : Nil
      current = @@active_fibers.get
      @@active_fibers.sub(1) if current > 0
    end

    def self.stats : String
      "active=#{@@active_fibers.get}, peak=#{@@peak_fibers.get}, spawns=#{@@fiber_spawns.get}"
    end

    def self.reset : Nil
      @@peak_fibers.set(@@active_fibers.get)
    end
  end

  # -------------------------------------------------------------------------
  # Health monitoring
  # -------------------------------------------------------------------------

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

    def self.feed_fetch_started : Nil
      @@feeds_in_progress.add(1)
    end

    def self.feed_fetch_completed : Nil
      current = @@feeds_in_progress.get
      @@feeds_in_progress.sub(1) if current > 0
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

    def self.attempt_recovery : Bool
      start_time = @@last_refresh_start.get
      return false if start_time == 0

      last_complete = @@last_refresh_complete.get
      return false if last_complete > start_time

      old_value = @@last_refresh_start.get
      return false if old_value == 0

      @@last_refresh_start.set(0)
      Log.for("quickheadlines.feed").info { "RefreshHealthMonitor: atomic recovery performed" }
      true
    end

    def self.force_stuck!(seconds : Int32 = 600) : Nil
      now_ms = Time.utc.to_unix_ms
      @@last_refresh_start.set(now_ms - (seconds * 1000))
      @@last_refresh_complete.set(0)
      Log.for("quickheadlines.watchdog").info { "RefreshHealthMonitor: forced stuck state for testing (#{seconds}s)" }
    end
  end

  # -------------------------------------------------------------------------
  # Loop state
  # -------------------------------------------------------------------------

  private class State
    property active_config : Config
    property last_mtime : Time
    property cycle_count : Int32
    property consecutive_skips : Int32
    # Cancel channel for the in-flight initial refresh fiber, if any. The
    # supervisor sets this when the initial refresh is spawned, and the
    # fiber clears it in its ensure block. The supervisor reads it on
    # shutdown to signal cancellation.
    property initial_cancel_ch : Channel(Bool)?
    getter? first_run : Bool

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

  # -------------------------------------------------------------------------
  # Supervisor helpers
  # -------------------------------------------------------------------------

  private def self.check_stuck_recovery(stuck_threshold : Int32) : Nil
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

  private def self.check_semaphore_health : Nil
    @@repair_mutex.synchronize do
      available = CONCURRENCY_AVAILABLE.get
      return if available == CONCURRENCY_LIMIT
      missing = CONCURRENCY_LIMIT - available
      Log.for("quickheadlines.feed").warn { "Semaphore health check: #{available}/#{CONCURRENCY_LIMIT} slots available, repairing #{missing} missing" }
      missing.times do
        CONCURRENCY_SEMAPHORE.send(nil)
        CONCURRENCY_AVAILABLE.add(1)
      end
    end
  end

  private def self.reload_config_if_changed(config_path : String, state : State) : Nil
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

  private def self.run_initial_refresh(state : State, cache : FeedCache, db_service : DatabaseService) : Nil
    if state.active_config.debug?
      Log.for("quickheadlines.feed").debug { "Running initial refresh to fetch feeds" }
    end

    StateStore.refreshing = true
    config_for_initial = state.active_config
    cancel_ch = Channel(Bool).new(1)
    state.initial_cancel_ch = cancel_ch
    spawn(name: "initial_refresh") do
      begin
        refresh_all(config_for_initial, cache, db_service, cancel_ch)
      rescue CancelError
        Log.for("quickheadlines.feed").warn { "Initial refresh cancelled by supervisor" }
        RefreshHealthMonitor.record_failure
      rescue ex : Exception
        Log.for("quickheadlines.feed").error(exception: ex) { "Initial refresh failed" }
        RefreshHealthMonitor.record_failure
      ensure
        StateStore.refreshing = false
        state.initial_cancel_ch = nil
      end
    end

    if state.active_config.debug?
      Log.for("quickheadlines.feed").debug { "Initial refresh started in background" }
    end
  end

  private def self.run_timed_refresh(state : State, cache : FeedCache, db_service : DatabaseService) : Float64
    # Check memory pressure before starting refresh
    begin
      memory_status = MemoryMonitorActor.instance.get_memory_status
      case memory_status.pressure_level
      when .critical?
        Log.for("quickheadlines.feed").warn { "Skipping refresh due to critical memory pressure (RSS=#{memory_status.rss_mb.round(1)}MB)" }
        RefreshHealthMonitor.record_failure
        return 0.0
      when .high?
        Log.for("quickheadlines.feed").warn { "Refresh proceeding with high memory pressure (RSS=#{memory_status.rss_mb.round(1)}MB)" }
      end
    rescue ex : Exception
      Log.for("quickheadlines.feed").debug { "Memory pressure check failed: #{ex.message}" }
    end

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
      rescue CancelError
        Log.for("quickheadlines.feed").warn { "Refresh worker cancelled by supervisor" }
        RefreshHealthMonitor.record_failure
      rescue ex : Exception
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
      GCCollector.maybe_collect
      refresh_duration
    when timeout(outer_timeout)
      cancel_ch.send(true)
      StateStore.refreshing = false
      Log.for("quickheadlines.feed").error { "refresh_all timed out after #{outer_timeout.total_seconds.round}s - worker signalled to cancel" }
      RefreshHealthMonitor.record_failure
      GCCollector.maybe_collect
      (Time.utc - refresh_start_time).total_seconds
    end
  end

  private def self.sleep_between_cycles(state : State) : Nil
    sleep_duration = state.refresh_interval_seconds.seconds
    outer_sleep_timeout = state.sleep_timeout_seconds.seconds
    elapsed = Time::Span.zero
    check_interval = 30.seconds

    while elapsed < sleep_duration && elapsed < outer_sleep_timeout
      break if QuickHeadlines.shutting_down?
      remaining = {check_interval, sleep_duration - elapsed, outer_sleep_timeout - elapsed}.min
      select
      when timeout(remaining)
        elapsed += remaining
      end
    end

    if elapsed >= outer_sleep_timeout && !QuickHeadlines.shutting_down?
      Log.for("quickheadlines.feed").error { "refresh loop sleep timed out after #{outer_sleep_timeout.total_seconds.round}s" }
    end
  end

  private def self.log_heartbeat(state : State) : Nil
    return unless state.heartbeat_due?(state.heartbeat_interval)

    status = RefreshHealthMonitor.status
    memory_growth = begin
      StateStore.memory_growth_rate
    rescue ex : Exception
      Log.for("quickheadlines.feed").debug(exception: ex) { "memory_growth_rate unavailable" }
      "unavailable"
    end

    Log.for("quickheadlines.feed").info do
      "Refresh loop heartbeat: #{state.cycle_count} cycles, " \
      "completed: #{status[:cycles]}, failures: #{status[:failures]}, " \
      "memory_growth: #{memory_growth}"
    end
  end

  private def self.start_health_reporter : Nil
    spawn(name: "health_monitor_reporter") do
      loop do
        begin
          break if QuickHeadlines.shutting_down?

          elapsed = Time::Span.zero
          while elapsed < 5.minutes
            break if QuickHeadlines.shutting_down?
            check = {30.seconds, 5.minutes - elapsed}.min
            select
            when timeout(check)
              elapsed += check
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
            memory_status = MemoryMonitorActor.instance.get_memory_status

            # Get diagnostic info
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

  # -------------------------------------------------------------------------
  # Public API — entry points for refresh loop
  # -------------------------------------------------------------------------

  # Main refresh function used by the supervisor.
  def self.refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Bool)? = nil) : Nil
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
    load_result = load_validated_config(config_path)
    unless load_result.success && (initial_config = load_result.config)
      Log.for("quickheadlines.feed").error { "Failed to load config: #{load_result.error_message}" }
      return
    end

    state = State.new(initial_config, File.info(config_path).modification_time)
    cache.save(state.active_config.cache_retention_hours, state.active_config.max_cache_size_mb)

    spawn(name: "refresh_supervisor") do
      loop do
        begin
          break if QuickHeadlines.shutting_down?

          check_stuck_recovery(state.stuck_threshold_seconds)

          if StateStore.refreshing?
            skip_count = state.increment_skips
            if skip_count >= State::MAX_CONSECUTIVE_SKIPS
              Log.for("quickheadlines.feed").error { "Force-resetting refreshing flag after #{skip_count} consecutive skips - previous refresh may be stuck" }
              StateStore.refreshing = false
              state.reset_skips
            else
              Log.for("quickheadlines.feed").warn { "Refresh already in progress, skipping (#{skip_count}/#{State::MAX_CONSECUTIVE_SKIPS})" }
              sleep state.refresh_interval_seconds.seconds
              break if QuickHeadlines.shutting_down?
              next
            end
          else
            state.reset_skips
          end

          check_semaphore_health

          if state.first_run?
            state.mark_first_run_done
            run_initial_refresh(state, cache, db_service)
            elapsed = Time::Span.zero
            while elapsed < state.refresh_interval_seconds.seconds
              if QuickHeadlines.shutting_down?
                # Signal cancellation to the in-flight initial refresh so
                # the worker can exit cleanly instead of running to
                # completion in the background. The worker's ensure block
                # clears state.initial_cancel_ch.
                if cancel_ch = state.initial_cancel_ch
                  cancel_ch.send(true) rescue nil
                end
                break
              end
              check = {30.seconds, state.refresh_interval_seconds.seconds - elapsed}.min
              select
              when timeout(check)
                elapsed += check
              end
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
        rescue ex : Exception
          Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop outer handler: unhandled exception, restarting in 60s" }
          StateStore.refreshing = false
          RefreshHealthMonitor.record_failure
          state.reset_cycle_count
          elapsed = Time::Span.zero
          while elapsed < 60.seconds
            break if QuickHeadlines.shutting_down?
            check = {30.seconds, 60.seconds - elapsed}.min
            select
            when timeout(check)
              elapsed += check
            end
          end
          break if QuickHeadlines.shutting_down?
        end
      end
    end

    start_health_reporter
  end
end

# Expose RefreshHealthMonitor at top level for existing callers (e.g., admin_controller, api_base_controller).
# The module is now nested inside RefreshLoop but we re-export it for API compatibility.
alias RefreshHealthMonitor = RefreshLoop::RefreshHealthMonitor

# Public API — backward-compatible top-level entry points that delegate to
# RefreshLoop module. This preserves the existing require/use surface without
# requiring callers to change.

# Convenience: refresh_all with default services
def refresh_all(config : Config, cancel_ch : Channel(Bool)? = nil)
  RefreshLoop.refresh_all(config, FeedCache.instance, DatabaseService.instance, cancel_ch)
end

# Full refresh_all with injected services
def refresh_all(config : Config, cache : FeedCache, db_service : DatabaseService, cancel_ch : Channel(Bool)? = nil)
  RefreshLoop.refresh_all(config, cache, db_service, cancel_ch)
end

# Start the refresh loop
def start_refresh_loop(config_path : String, cache : FeedCache, db_service : DatabaseService)
  RefreshLoop.start(config_path, cache, db_service)
end
