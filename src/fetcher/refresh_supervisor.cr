require "log"
require "../config"
require "../config/loader"
require "../models"
require "../storage"
require "../constants"
require "../services/gc_collector"
require "../services/memory_manager_actor"
require "../websocket"
require "./feed_fetcher_concurrent"
require "./interruptible_sleep"
require "./monitoring"
require "./semaphore_pool"
require "../services/fiber_tracker"

# Long-lived refresh loop supervisor.
#
# Owns:
# - The `State` class (lifecycle counters, cancel channel, first-run flag)
# - The main supervisor loop (stuck-recovery, semaphore health, first-run
#   vs. regular cycle, sleep between cycles, heartbeat)
# - Configuration reload and validation
#
# The Supervisor used to own a private `interruptible_sleep` helper;
# that primitive now lives in `RefreshLoop::InterruptibleSleep` and
# is shared with the health reporter.
# - The periodic health/memory reporter kick-off
#
# Public API: `Supervisor.start(config_path, cache, db_service, semaphore)`
# spawns the supervisor fiber and the health reporter, then returns.
#
# The class takes its dependencies in the constructor so it can be
# inspected in tests. `interruptible_sleep` is a private class method
# (the Supervisor is the only remaining consumer after the
# supervisor-related code moved out of `refresh_loop.cr`).
module RefreshLoop
  class Supervisor
    RESTART_DELAY_AFTER_ERROR  = 60.seconds
    HEARTBEAT_INTERVAL         = 10
    LONG_REFRESH_DURATION_WARN = 120.seconds

    def self.start(config_path : String, cache : FeedCache, db_service : DatabaseService, semaphore : SemaphorePool) : Nil
      load_result = load_validated_config(config_path)
      unless load_result.success && (initial_config = load_result.config)
        Log.for("quickheadlines.feed").error { "Failed to load config: #{load_result.error_message}" }
        return
      end
      new(initial_config, config_path, cache, db_service, semaphore).run
    end

    getter state : State

    @cache : FeedCache
    @db_service : DatabaseService
    @config_path : String
    @semaphore : SemaphorePool

    def initialize(initial_config : Config, @config_path : String, @cache : FeedCache, @db_service : DatabaseService, @semaphore : SemaphorePool)
      @state = State.new(initial_config, File.info(@config_path).modification_time)
    end

    def run : Nil
      @cache.save(@state.active_config.cache_retention_hours, @state.active_config.max_cache_size_mb)
      RefreshLoop::FiberTracker.tracked_spawn("refresh_supervisor") do
        loop do
          break if QuickHeadlines.shutting_down?
          run_one_iteration
        rescue ex : Exception
          handle_outer_error(ex)
        end
      end
    end

    # One cycle of the supervisor loop. Extracted from the original
    # 70-line `start` body so each branch is readable on its own.
    private def run_one_iteration : Nil
      check_stuck_recovery
      return if handle_refreshing_state
      check_semaphore_health
      if @state.first_run?
        run_first_cycle
      else
        run_regular_cycle
      end
    end

    # Branch on `StateStore.refreshing?`. Returns `true` if the rest of
    # the cycle should be skipped (caller should `return`). Also
    # force-resets the refreshing flag after MAX_CONSECUTIVE_SKIPS, in
    # which case the cycle continues with the rest of the work.
    private def handle_refreshing_state : Bool
      unless StateStore.refreshing?
        @state.reset_skips
        return false
      end

      skip_count = @state.increment_skips
      if skip_count >= State::MAX_CONSECUTIVE_SKIPS
        Log.for("quickheadlines.feed").error { "Force-resetting refreshing flag after #{skip_count} consecutive skips - previous refresh may be stuck" }
        StateStore.refreshing = false
        @state.reset_skips
        false
      else
        Log.for("quickheadlines.feed").warn { "Refresh already in progress, skipping (#{skip_count}/#{State::MAX_CONSECUTIVE_SKIPS})" }
        RefreshLoop::InterruptibleSleep.sleep(@state.refresh_interval_seconds.seconds)
        true
      end
    end

    private def run_first_cycle : Nil
      @state.mark_first_run_done
      run_initial_refresh
      RefreshLoop::InterruptibleSleep.sleep(@state.refresh_interval_seconds.seconds)
      if QuickHeadlines.shutting_down?
        # Signal cancellation to the in-flight initial refresh so the
        # worker can exit cleanly instead of running to completion in
        # the background. The worker's ensure block clears
        # state.initial_cancel_ch.
        if cancel_ch = @state.initial_cancel_ch
          cancel_ch.send(nil) rescue nil
        end
      end
    end

    private def run_regular_cycle : Nil
      reload_config_if_changed
      refresh_duration = run_timed_refresh
      log_duration_warning(refresh_duration, @state.active_config)
      sleep_between_cycles
      return if QuickHeadlines.shutting_down?
      @state.increment_cycle
      log_heartbeat
    end

    private def handle_outer_error(ex : Exception) : Nil
      Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop outer handler: unhandled exception, restarting in #{RESTART_DELAY_AFTER_ERROR.total_seconds.round}s" }
      StateStore.refreshing = false
      RefreshLoop::Monitoring.record_failure
      @state.reset_cycle_count
      RefreshLoop::InterruptibleSleep.sleep(RESTART_DELAY_AFTER_ERROR)
    end

    # Sleep for up to `total` duration, broken into `chunk`-sized
    # timeouts that check QuickHeadlines.shutting_down? between each.
    # Returns the actual elapsed time (which is < total if shutdown was
    # signaled, or == total on natural completion). Optional `outer_cap`
    # adds a hard ceiling: if non-nil, the loop exits when elapsed >=
    # outer_cap even if `total` has not been reached. Default chunk is
    # 30s which gives a responsive shutdown signal without burning CPU.
    private def check_stuck_recovery : Nil
      return unless RefreshLoop::Monitoring.stuck?(@state.stuck_threshold_seconds)

      status = RefreshLoop::Monitoring.status
      Log.for("quickheadlines.feed").error do
        "REFRESH STUCK: last cycle started at #{status[:last_start]}, " \
        "cycles completed: #{status[:cycles]}, failures: #{status[:failures]}"
      end
      Log.for("quickheadlines.feed").error { "Attempting to recover stuck refresh..." }

      if RefreshLoop::Monitoring.attempt_recovery
        StateStore.update(&.copy_with(refreshing: false))
        RefreshLoop::Monitoring.reset_failures
        Log.for("quickheadlines.feed").info { "Recovery complete, will retry on next cycle" }
      else
        Log.for("quickheadlines.feed").info { "Recovery was already performed by another fiber" }
      end
    end

    private def check_semaphore_health : Nil
      before = @semaphore.health_status[:available]
      missing = @semaphore.repair
      if missing > 0
        Log.for("quickheadlines.feed").warn { "Semaphore health check: #{before}/#{@semaphore.limit} slots available, repairing #{missing} missing" }
      end
    end

    private def reload_config_if_changed : Nil
      current_mtime = begin
        File.info(@config_path).modification_time
      rescue ex : File::NotFoundError
        if @state.active_config.debug?
          Log.for("quickheadlines.feed").debug { "reload_config_if_changed: #{@config_path} not found, skipping reload (#{ex.message})" }
        end
        return
      end
      return unless current_mtime > @state.last_mtime

      load_result = load_validated_config(@config_path)
      if load_result.success && (new_config = load_result.config)
        @state.active_config = new_config
        @state.last_mtime = current_mtime
        if @state.active_config.debug?
          Log.for("quickheadlines.feed").debug { "Config change detected. Reloaded feeds.yml" }
        end
      end
    end

    private def run_initial_refresh : Nil
      if @state.active_config.debug?
        Log.for("quickheadlines.feed").debug { "Running initial refresh to fetch feeds" }
      end

      StateStore.refreshing = true
      config_for_initial = @state.active_config
      cancel_ch = Channel(Nil).new(1)
      @state.initial_cancel_ch = cancel_ch
      RefreshLoop::FiberTracker.tracked_spawn("initial_refresh") do
        begin
          refresh_all(config_for_initial, @cache, @db_service, cancel_ch)
        rescue CancelError
          Log.for("quickheadlines.feed").warn { "Initial refresh cancelled by supervisor" }
          RefreshLoop::Monitoring.record_failure
        rescue ex : Exception
          Log.for("quickheadlines.feed").error(exception: ex) { "Initial refresh failed" }
          RefreshLoop::Monitoring.record_failure
        ensure
          StateStore.refreshing = false
          @state.initial_cancel_ch = nil
        end
      end

      if @state.active_config.debug?
        Log.for("quickheadlines.feed").debug { "Initial refresh started in background" }
      end
    end

    private def run_timed_refresh : Float64
      # Check memory pressure before starting refresh
      begin
        memory_status = MemoryManagerActor.instance.get_memory_status
        case memory_status.pressure_level
        when .critical?
          Log.for("quickheadlines.feed").warn { "Skipping refresh due to critical memory pressure (RSS=#{memory_status.rss_mb.round(1)}MB)" }
          RefreshLoop::Monitoring.record_failure
          return 0.0
        when .high?
          Log.for("quickheadlines.feed").warn { "Refresh proceeding with high memory pressure (RSS=#{memory_status.rss_mb.round(1)}MB)" }
        end
      rescue ex : Exception
        Log.for("quickheadlines.feed").debug { "Memory pressure check failed: #{ex.message}" }
      end

      StateStore.refreshing = true
      refresh_start_time = Time.utc
      outer_timeout = @state.outer_timeout_seconds.seconds
      config_snapshot = @state.active_config
      refresh_all_start = Time.utc

      cancel_ch = Channel(Nil).new(1)
      completion_channel = Channel(Nil).new(1)
      RefreshLoop::FiberTracker.tracked_spawn("refresh_worker") do
        begin
          refresh_all(config_snapshot, @cache, @db_service, cancel_ch)
          refresh_all_duration = (Time.utc - refresh_all_start).total_seconds
          if config_snapshot.debug?
            Log.for("quickheadlines.feed").debug { "Refreshed feeds in #{refresh_all_duration.round(2)}s" }
          elsif refresh_all_duration > LONG_REFRESH_DURATION_WARN.total_seconds
            Log.for("quickheadlines.feed").warn { "refresh_all took #{refresh_all_duration.round(2)}s - long duration" }
          end
        rescue CancelError
          Log.for("quickheadlines.feed").warn { "Refresh worker cancelled by supervisor" }
          RefreshLoop::Monitoring.record_failure
        rescue ex : Exception
          Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop refresh_all failed" }
          RefreshLoop::Monitoring.record_failure
        end
        completion_channel.send(nil)
      end

      select
      when completion_channel.receive?
        StateStore.refreshing = false
        refresh_duration = (Time.utc - refresh_start_time).total_seconds
        Log.for("quickheadlines.feed").debug { "Starting save_feed_cache..." }
        @cache.save(config_snapshot.cache_retention_hours, config_snapshot.max_cache_size_mb)
        Log.for("quickheadlines.feed").debug { "save_feed_cache complete" }
        GCCollector.maybe_collect
        refresh_duration
      when timeout(outer_timeout)
        cancel_ch.send(nil)
        StateStore.refreshing = false
        Log.for("quickheadlines.feed").error { "refresh_all timed out after #{outer_timeout.total_seconds.round}s - worker signalled to cancel" }
        RefreshLoop::Monitoring.record_failure
        GCCollector.maybe_collect
        (Time.utc - refresh_start_time).total_seconds
      end
    end

    private def sleep_between_cycles : Nil
      sleep_duration = @state.refresh_interval_seconds.seconds
      outer_sleep_timeout = @state.sleep_timeout_seconds.seconds
      elapsed = RefreshLoop::InterruptibleSleep.sleep(sleep_duration, outer_cap: outer_sleep_timeout)

      if elapsed >= outer_sleep_timeout && !QuickHeadlines.shutting_down?
        Log.for("quickheadlines.feed").error { "refresh loop sleep timed out after #{outer_sleep_timeout.total_seconds.round}s" }
      end
    end

    private def log_heartbeat : Nil
      return unless @state.heartbeat_due?(HEARTBEAT_INTERVAL)

      status = RefreshLoop::Monitoring.status
      memory_growth = begin
        StateStore.memory_growth_rate
      rescue ex : Exception
        Log.for("quickheadlines.feed").debug(exception: ex) { "memory_growth_rate unavailable" }
        "unavailable"
      end

      Log.for("quickheadlines.feed").info do
        "Refresh loop heartbeat: #{@state.cycle_count} cycles, " \
        "completed: #{status[:cycles]}, failures=#{status[:failures]}, " \
        "memory_growth=#{memory_growth}"
      end
    end

    private def log_duration_warning(refresh_duration, active_config)
      expected_seconds = active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE
      hang_threshold = expected_seconds * 2
      if refresh_duration > hang_threshold
        Log.for("quickheadlines.feed").warn { "Refresh took #{refresh_duration.round(2)}s (expected #{expected_seconds}s) - possible hang detected" }
      end
    end

    # State for the supervisor's lifecycle: current config, last
    # reload time, cycle counter, consecutive-skip counter, the
    # in-flight cancel channel for the initial refresh fiber, and a
    # `first_run` flag that gates the special first-cycle logic.
    class State
      property active_config : Config
      property last_mtime : Time
      property cycle_count : Int32
      property consecutive_skips : Int32
      # Cancel channel for the in-flight initial refresh fiber, if any. The
      # supervisor sets this when the initial refresh is spawned, and the
      # fiber clears it in its ensure block. The supervisor reads it on
      # shutdown to signal cancellation.
      property initial_cancel_ch : Channel(Nil)?
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
        refresh_interval_seconds * QuickHeadlines::Constants::OUTER_TIMEOUT_SECONDS // 2
      end

      def sleep_timeout_seconds : Int32
        refresh_interval_seconds * QuickHeadlines::Constants::SLEEP_TIMEOUT_SECONDS // 2
      end

      def stuck_threshold_seconds : Int32
        refresh_interval_seconds * QuickHeadlines::Constants::STUCK_THRESHOLD_SECONDS
      end

      MAX_CONSECUTIVE_SKIPS = 3
    end
  end
end
