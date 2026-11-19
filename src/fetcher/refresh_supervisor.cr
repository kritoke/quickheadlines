require "log"
require "../config"
require "../config/loader"
require "../models"
require "../storage"
require "../constants"
require "../services/gc_collector"
require "../websocket"
require "./feed_fetcher_concurrent"
require "./interruptible_sleep"
require "./monitoring"
require "../services/fiber_tracker"

# Long-lived refresh loop supervisor.
#
# Each cycle runs one refresh in a worker fiber bounded by an outer
# timeout (refresh interval * OUTER_TIMEOUT_MULTIPLIER). On timeout the
# worker is signalled to cancel. While a cancelled worker is still alive,
# later cycles are skipped instead of spawning a second worker. This is the
# single stuck-refresh mechanism; it replaces the old watchdog fiber,
# Monitoring.stuck?/attempt_recovery and the consecutive-skip reset.
#
# Public API: `Supervisor.start(config_path, cache, db_service)`.
module RefreshLoop
  class Supervisor
    RESTART_DELAY_AFTER_ERROR  = 60.seconds
    HEARTBEAT_INTERVAL         = 10
    LONG_REFRESH_DURATION_WARN = 120.seconds

    def self.start(config_path : String, cache : FeedCache, db_service : DatabaseService) : Nil
      load_result = ConfigLoader.load_validated_config(config_path)
      unless load_result.success && (initial_config = load_result.config)
        Log.for("quickheadlines.feed").error { "Failed to load config: #{load_result.error_message}" }
        return
      end
      new(initial_config, config_path, cache, db_service).run
    end

    getter state : State

    @cache : FeedCache
    @db_service : DatabaseService
    @config_path : String
    # True while a refresh_worker fiber is alive, including one that was
    # signalled to cancel after the outer timeout but hasn't exited yet.
    @worker_alive = Atomic(Bool).new(false)
    @stuck_skips = 0

    def initialize(initial_config : Config, @config_path : String, @cache : FeedCache, @db_service : DatabaseService)
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

    private def run_one_iteration : Nil
      first = @state.first_run?
      @state.mark_first_run_done
      reload_config_if_changed unless first
      refresh_duration = run_timed_refresh
      log_duration_warning(refresh_duration, @state.active_config) unless first
      RefreshLoop::InterruptibleSleep.sleep(@state.refresh_interval_seconds.seconds)
      return if QuickHeadlines.shutting_down? || first
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

      load_result = ConfigLoader.load_validated_config(@config_path)
      if load_result.success && (new_config = load_result.config)
        @state.active_config = new_config
        @state.last_mtime = current_mtime
        if @state.active_config.debug?
          Log.for("quickheadlines.feed").debug { "Config change detected. Reloaded feeds.yml" }
        end
      end
    end

    private def run_timed_refresh : Float64
      if @worker_alive.get
        @stuck_skips += 1
        Log.for("quickheadlines.feed").warn { "Previous refresh worker still running (cancelled, not yet exited) - skipping this cycle (#{@stuck_skips})" }
        RefreshLoop::Monitoring.record_failure
        if QuickHeadlines::Constants::WATCHDOG_ESCALATE_EXIT && @stuck_skips >= QuickHeadlines::Constants::STUCK_WORKER_EXIT_AFTER_SKIPS
          Log.for("quickheadlines.feed").fatal { "Refresh worker wedged for #{@stuck_skips} cycles - exiting for external supervisor restart" }
          exit 1
        end
        return 0.0
      end
      @stuck_skips = 0

      StateStore.refreshing = true
      refresh_start_time = Time.utc
      outer_timeout = @state.outer_timeout_seconds.seconds
      config_snapshot = @state.active_config
      refresh_all_start = Time.utc

      cancel_ch = Channel(Nil).new(1)
      completion_channel = Channel(Nil).new(1)
      @worker_alive.set(true)
      RefreshLoop::FiberTracker.tracked_spawn("refresh_worker") do
        begin
          # Use local variable to avoid holding config reference after refresh
          cfg = config_snapshot
          RefreshLoop.refresh_all(cfg, @cache, @db_service, cancel_ch)
          refresh_all_duration = (Time.utc - refresh_all_start).total_seconds
          if cfg.debug?
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
        ensure
          @worker_alive.set(false)
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
        GCCollector.collect_now
        refresh_duration
      when timeout(outer_timeout)
        cancel_ch.send(nil)
        StateStore.refreshing = false
        Log.for("quickheadlines.feed").error { "refresh_all timed out after #{outer_timeout.total_seconds.round}s - worker signalled to cancel" }
        RefreshLoop::Monitoring.record_failure
        GCCollector.collect_now
        (Time.utc - refresh_start_time).total_seconds
      end
    end

    private def log_heartbeat : Nil
      return unless @state.heartbeat_due?(HEARTBEAT_INTERVAL)

      status = RefreshLoop::Monitoring.status
      Log.for("quickheadlines.feed").info do
        "Refresh loop heartbeat: #{@state.cycle_count} cycles, " \
        "completed: #{status[:cycles]}, failures=#{status[:failures]}"
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
    # reload time, cycle counter, and a `first_run` flag.
    class State
      property active_config : Config
      property last_mtime : Time
      property cycle_count : Int32
      getter? first_run : Bool

      @first_run : Bool = true

      def initialize(@active_config : Config, @last_mtime : Time)
        @cycle_count = 0
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

      def refresh_interval_seconds : Int32
        active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE
      end

      def outer_timeout_seconds : Int32
        (refresh_interval_seconds * QuickHeadlines::Constants::OUTER_TIMEOUT_MULTIPLIER).to_i
      end
    end
  end
end
