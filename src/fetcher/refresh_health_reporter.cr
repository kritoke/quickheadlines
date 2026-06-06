require "../config"
require "../services/memory_manager_actor"
require "../websocket"
require "../services/fiber_tracker"
require "./refresh_health_monitor"

module RefreshLoop
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
    repair_mutex.synchronize do
      available = semaphore_counter.get
      return if available == CONCURRENCY_LIMIT
      missing = CONCURRENCY_LIMIT - available
      Log.for("quickheadlines.feed").warn { "Semaphore health check: #{available}/#{CONCURRENCY_LIMIT} slots available, repairing #{missing} missing" }
      missing.times do
        semaphore.send(nil)
        semaphore_counter.add(1)
      end
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

          interruptible_sleep(5.minutes)

          break if QuickHeadlines.shutting_down?
          status = RefreshHealthMonitor.status
          if status[:failures] > 0 || status[:last_complete] == 0
            Log.for("quickheadlines.feed").warn do
              "Refresh health: cycles=#{status[:cycles]}, failures=#{status[:failures]}, last_complete=#{status[:last_complete]}"
            end
          end

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
        rescue ex : Exception
          Log.for("quickheadlines.feed").error(exception: ex) { "Health monitor reporter error" }
        end
      end
    end
  end
end
