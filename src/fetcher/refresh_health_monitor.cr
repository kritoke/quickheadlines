# Health monitoring for the refresh loop supervisor.
#
# Tracks refresh cycle start/complete timestamps, cycle counts, failure
# counts, and feeds-in-progress counts. Exposes `stuck?` and
# `attempt_recovery` so the supervisor can detect and recover from a
# refresh cycle that never finished. Also exposes two
# `*_for_testing=` setters used exclusively by
# `src/dev_tools/refresh_simulator.cr` to simulate a stuck state.
module RefreshLoop::RefreshHealthMonitor
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

  # Public accessors for dev tooling. The simulation lives in
  # `src/dev_tools/refresh_simulator.cr` (see QuickHeadlines::DevRefreshSimulator)
  # which is the only intended caller. These setters are explicit
  # about their dev intent so they are easy to grep for and audit.
  def self.last_refresh_start_for_testing=(ms : Int64) : Nil
    @@last_refresh_start.set(ms)
  end

  def self.last_refresh_complete_for_testing=(ms : Int64) : Nil
    @@last_refresh_complete.set(ms)
  end
end
