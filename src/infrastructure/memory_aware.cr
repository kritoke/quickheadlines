# MemoryAware - Mixin for automatic memory checking in actors
#
# This mixin provides:
# 1. Automatic memory checks before heavy operations
# 2. Memory pressure detection
# 3. Automatic GC triggers
# 4. Budget enforcement
#
# Usage:
#   class MyActor < Actor
#     include MemoryAware
#
#     private def handle_heavy_operation
#       return unless check_memory_budget("my_operation", 50.0)
#       # ... operation logic
#     end
#   end
#
module MemoryAware
  macro included
    @@last_memory_check : Time = Time.utc
    @@memory_check_interval : Time::Span = 30.seconds

    # Check if memory budget is available
    private def check_memory_budget(subsystem : String, amount_mb : Float64) : Bool
      begin
        MemoryBudgetActor.instance.can_allocate?(subsystem, amount_mb)
      rescue ex
        Log.for("quickheadlines.memory").warn { "Memory budget check failed: #{ex.message}" }
        true # Allow operation if budget check fails
      end
    end

    # Check memory pressure level
    private def check_memory_pressure : MemoryMonitorActor::PressureLevel
      begin
        status = MemoryMonitorActor.instance.get_memory_status
        status.pressure_level
      rescue ex
        Log.for("quickheadlines.memory").warn { "Memory pressure check failed: #{ex.message}" }
        MemoryMonitorActor::PressureLevel::Low
      end
    end

    # Maybe check memory (throttled)
    private def maybe_check_memory : Nil
      now = Time.utc
      return if (now - @@last_memory_check) < @@memory_check_interval
      @@last_memory_check = now

      begin
        MemoryMonitorActor.instance.check_and_gc
      rescue ex
        Log.for("quickheadlines.memory").debug { "Memory check failed: #{ex.message}" }
      end
    end

    # Check if operation should be skipped due to memory pressure
    private def should_skip_due_to_memory?(subsystem : String, amount_mb : Float64) : Bool
      pressure = check_memory_pressure

      case pressure
      when .critical?
        Log.for("quickheadlines.memory").warn { "Skipping #{subsystem} due to critical memory pressure" }
        true
      when .high?
        # Only skip if not essential
        unless subsystem == "memory_management" || subsystem == "shutdown"
          Log.for("quickheadlines.memory").debug { "Skipping #{subsystem} due to high memory pressure" }
          return true
        end
        false
      else
        false
      end
    end

    # Log memory usage
    private def log_memory_usage(context : String) : Nil
      begin
        status = MemoryMonitorActor.instance.get_memory_status
        Log.for("quickheadlines.memory").debug { "#{context}: RSS=#{status.rss_mb.round(1)}MB, pressure=#{status.pressure_level}" }
      rescue ex
        Log.for("quickheadlines.memory").debug { "#{context}: Unable to get memory status" }
      end
    end
  end
end
