require "log"
require "../constants"
require "../websocket"
require "../services/memory_manager_actor"
require "../services/fiber_tracker"
require "./refresh_health_monitor"

# Periodic health and memory reporter.
#
# Spawns a long-lived fiber that wakes every REPORT_INTERVAL and
# logs refresh-cycle health (from `RefreshHealthMonitor`) plus
# memory status with diagnostic counts (sockets, event clients,
# fibers). The reporter is on the suspect list for the in-flight
# P0 memory-growth investigation (`quickhea-alz`); this file does
# not modify behavior — it just moves the code out of
# `refresh_loop.cr` so it can be reasoned about in isolation.
#
# Follows the convention already established by
# `src/fetcher/refresh_health_monitor.cr` (one file, one concern,
# public class-level methods on a `RefreshLoop::*` sub-module).
module RefreshLoop
  module HealthReporter
    REPORT_INTERVAL = 5.minutes
    SHUTDOWN_CHUNK  = 30.seconds

    def self.start : Nil
      spawn(name: "health_monitor_reporter") do
        loop do
          break if QuickHeadlines.shutting_down?
          interruptible_sleep(REPORT_INTERVAL)
          break if QuickHeadlines.shutting_down?
          report_status
        rescue ex : Exception
          Log.for("quickheadlines.feed").error(exception: ex) { "Health monitor reporter error" }
        end
      end
    end

    # Sleeps for `total`, broken into SHUTDOWN_CHUNK-sized waits that
    # check `QuickHeadlines.shutting_down?` between each. Kept local
    # because the parent module's `interruptible_sleep` is private to
    # `RefreshLoop` and not reachable from a sub-module. If a shared
    # sleep utility is extracted later (ticket `quickhea-az6.5` /
    # `quickhea-az6.7`), this can be replaced with that helper.
    private def self.interruptible_sleep(total : Time::Span) : Nil
      elapsed = Time::Span.zero
      while elapsed < total && !QuickHeadlines.shutting_down?
        step = {SHUTDOWN_CHUNK, total - elapsed}.min
        select
        when timeout(step)
          elapsed += step
        end
      end
    end

    private def self.report_status : Nil
      status = RefreshHealthMonitor.status
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
end
