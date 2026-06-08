require "log"
require "../module"
require "../constants"
require "../websocket"
require "../services/memory_manager_actor"
require "../services/fiber_tracker"
require "./interruptible_sleep"

# Refresh loop monitoring.
#
# Owns the full lifecycle of the refresh loop's observability:
#
# - State tracking: `record_cycle_start`, `record_cycle_complete`,
#   `record_failure`, `reset_failures`, `feed_fetch_started`,
#   `feed_fetch_completed`, `status`. These are called from
#   the supervisor and the per-feed fetcher.
# - Stuck detection and recovery: `stuck?` and `attempt_recovery`,
#   called from the supervisor's `check_stuck_recovery` and from
#   `app_bootstrap`.
# - Periodic logging: `start` spawns a long-lived fiber that
#   wakes every `REPORT_INTERVAL` and logs refresh-cycle health
#   plus memory status with diagnostic counts (sockets, event
#   clients, fibers). The reporter is on the suspect list for
#   the in-flight P0 memory-growth investigation (`quickhea-alz`).
# - Test-only setters: `last_refresh_start_for_testing=` and
#   `last_refresh_complete_for_testing=` are used exclusively by
#   `src/dev_tools/refresh_simulator.cr` to simulate a stuck
#   state.
#
# History: this module merges what used to be two separate
# `RefreshLoop::*` sub-modules — `RefreshHealthMonitor`
# (state tracking + stuck detection) and `HealthReporter`
# (periodic logging). They shared the same `Log.for("quickheadlines.feed")`
# namespace, the same status data, and the same actor pattern.
# Splitting them across two files meant the relationship was
# implicit and the periodic logger's name was awkward
# (`HealthReporter.start` had nothing to do with `HealthReporter.status`
# callers elsewhere). See ticket quickhea-pow.
module RefreshLoop::Monitoring
  REPORT_INTERVAL = 5.minutes

  @@last_refresh_start : Atomic(Int64) = Atomic(Int64).new(0)
  @@last_refresh_complete : Atomic(Int64) = Atomic(Int64).new(0)
  @@refresh_cycles_completed : Atomic(Int32) = Atomic(Int32).new(0)
  @@refresh_failures : Atomic(Int32) = Atomic(Int32).new(0)
  @@feeds_in_progress : Atomic(Int32) = Atomic(Int32).new(0)

  # ---------------------------------------------------------------------
  # State tracking
  # ---------------------------------------------------------------------

  def self.record_cycle_start : Nil
    now_ms = Time.utc.to_unix_ms
    @@last_refresh_start.set(now_ms)
    Log.for("quickheadlines.feed").debug { "Monitoring: cycle start recorded at #{now_ms}" }
  end

  def self.record_cycle_complete : Nil
    now_ms = Time.utc.to_unix_ms
    @@last_refresh_complete.set(now_ms)
    @@refresh_cycles_completed.add(1)
    Log.for("quickheadlines.feed").debug { "Monitoring: cycle complete at #{now_ms}, total cycles=#{@@refresh_cycles_completed.get}" }
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

  # ---------------------------------------------------------------------
  # Stuck detection and recovery
  # ---------------------------------------------------------------------

  def self.stuck?(max_age_seconds : Int32) : Bool
    start_time = @@last_refresh_start.get
    return false if start_time == 0

    last_complete = @@last_refresh_complete.get
    return false if last_complete > start_time

    age_ms = Time.utc.to_unix_ms - start_time
    result = age_ms > (max_age_seconds * 1000)
    if result
      Log.for("quickheadlines.feed").warn do
        "Monitoring.stuck?: start=#{start_time}, last_complete=#{last_complete}, age_ms=#{age_ms}, threshold_ms=#{max_age_seconds * 1000}"
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
    Log.for("quickheadlines.feed").info { "Monitoring: atomic recovery performed" }
    true
  end

  # ---------------------------------------------------------------------
  # Test-only setters (used by src/dev_tools/refresh_simulator.cr)
  # ---------------------------------------------------------------------

  def self.last_refresh_start_for_testing=(ms : Int64) : Nil
    @@last_refresh_start.set(ms)
  end

  def self.last_refresh_complete_for_testing=(ms : Int64) : Nil
    @@last_refresh_complete.set(ms)
  end

  # ---------------------------------------------------------------------
  # Periodic logging
  # ---------------------------------------------------------------------

  # Spawns a long-lived fiber that wakes every REPORT_INTERVAL and
  # logs refresh-cycle health (this module's own `status`) plus
  # memory status with diagnostic counts (sockets, event clients,
  # fibers).
  def self.start : Nil
    spawn(name: "health_monitor_reporter") do
      loop do
        break if QuickHeadlines.shutting_down?
        RefreshLoop::InterruptibleSleep.sleep(REPORT_INTERVAL)
        break if QuickHeadlines.shutting_down?
        report_status
      rescue ex : Exception
        Log.for("quickheadlines.feed").error(exception: ex) { "Monitoring reporter error" }
      end
    end
  end

  private def self.report_status : Nil
    status = Monitoring.status
    if status[:failures] > 0 || status[:last_complete] == 0
      Log.for("quickheadlines.feed").warn do
        "Refresh health: cycles=#{status[:cycles]}, failures=#{status[:failures]}, last_complete=#{status[:last_complete]}"
      end
    end

    # Log memory status with diagnostics. Each diagnostic counter is
    # best-effort: a failure in one should not silence the others or
    # kill the reporter loop.
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
  end
end
