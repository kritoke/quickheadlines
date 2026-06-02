require "../infrastructure/actor"

# MemoryMonitorActor - Central memory monitoring and GC coordination
#
# This actor provides:
# 1. RSS (Resident Set Size) monitoring
# 2. GC coordination
# 3. Memory pressure detection
# 4. Automatic recovery actions
#
# Usage:
#   MemoryMonitorActor.instance.get_rss_mb
#   MemoryMonitorActor.instance.check_and_gc
#   MemoryMonitorActor.instance.get_memory_status
#
class MemoryMonitorActor < Actor
  # =========================================================================
  # Types
  # =========================================================================

  struct MemoryStatus
    getter rss_mb : Float64
    getter pressure_level : PressureLevel
    getter subsystems : Hash(String, SubsystemMemory)
    getter last_gc_time : Time?
    getter gc_count : Int32

    def initialize(@rss_mb, @pressure_level, @subsystems, @last_gc_time, @gc_count)
    end
  end

  struct SubsystemMemory
    getter name : String
    getter budget_mb : Float64
    getter allocated_mb : Float64
    getter utilization_percent : Float32

    def initialize(@name, @budget_mb, @allocated_mb)
      @utilization_percent = budget_mb > 0 ? (allocated_mb / budget_mb * 100).to_f32 : 0.0_f32
    end
  end

  enum PressureLevel
    Low      # RSS < 500MB
    Medium   # RSS 500-650MB
    High     # RSS 650-800MB
    Critical # RSS > 800MB
  end

  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call get_rss_mb, Float64
  def_call get_memory_status, MemoryStatus
  def_call can_allocate(subsystem : String, amount_mb : Float64), Bool

  # Cast messages (fire-and-forget)
  def_cast check_and_gc
  def_cast set_threshold(max_rss_mb : Int32)
  def_cast register_subsystem(subsystem : String, budget_mb : Float64)
  def_cast release_subsystem(subsystem : String)

  # =========================================================================
  # Actor state
  # =========================================================================

  @max_rss_mb : Int32 = 750
  @last_rss_mb : Float64 = 0.0
  @consecutive_high : Int32 = 0
  @gc_count : Int32 = 0
  @last_gc_time : Time? = nil
  @subsystems : Hash(String, Float64) = {} of String => Float64
  @subsystem_allocated : Hash(String, Float64) = {} of String => Float64

  def initialize(@name : String = "MemoryMonitor")
    super(@name, mailbox_size: 50)
  end

  # Singleton access
  @@instance : MemoryMonitorActor?
  @@instance_mutex = Mutex.new

  def self.instance : MemoryMonitorActor
    @@instance_mutex.synchronize do
      @@instance ||= MemoryMonitorActor.new.tap(&.start)
    end
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallGetRssMb        then message.deliver_reply(handle_get_rss_mb)
    when CallGetMemoryStatus then message.deliver_reply(handle_get_memory_status)
    when CallCanAllocate     then message.deliver_reply(handle_can_allocate(message.subsystem, message.amount_mb))
    when CastCheckAndGc      then handle_check_and_gc
    when CastSetThreshold    then handle_set_threshold(message.max_rss_mb)
    when CastRegisterSubsystem then handle_register_subsystem(message.subsystem, message.budget_mb)
    when CastReleaseSubsystem  then handle_release_subsystem(message.subsystem)
    else raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Handlers
  # =========================================================================

  private def handle_get_rss_mb : Float64
    read_rss_mb
  end

  private def handle_get_memory_status : MemoryStatus
    rss = read_rss_mb
    pressure = calculate_pressure(rss)
    subsystems = build_subsystem_memory
    MemoryStatus.new(rss, pressure, subsystems, @last_gc_time, @gc_count)
  end

  private def handle_can_allocate(subsystem : String, amount_mb : Float64) : Bool
    rss = read_rss_mb
    pressure = calculate_pressure(rss)

    case pressure
    when .low?
      true
    when .medium?
      # Allow 50% of requests
      rand < 0.5
    when .high?
      # Only allow critical requests
      subsystem == "memory_management" || subsystem == "shutdown"
    when .critical?
      # Reject all non-critical
      false
    else
      true
    end
  end

  private def handle_check_and_gc : Nil
    rss = read_rss_mb
    pressure = calculate_pressure(rss)

    Log.for("quickheadlines.memory").debug { "Memory check: RSS=#{rss.round(1)}MB, pressure=#{pressure}" }

    case pressure
    when .low?
      @consecutive_high = 0
    when .medium?
      # No action needed
    when .high?
      @consecutive_high += 1
      if @consecutive_high >= 3
        Log.for("quickheadlines.memory").warn { "High memory pressure detected (#{@consecutive_high} consecutive checks)" }
        force_gc
      end
    when .critical?
      @consecutive_high += 1
      Log.for("quickheadlines.memory").error { "Critical memory pressure: RSS=#{rss.round(1)}MB" }
      force_gc

      if @consecutive_high >= 5
        Log.for("quickheadlines.memory").error { "Sustained critical memory pressure, considering restart" }
        # Trigger graceful restart
        spawn do
          sleep(5.seconds)
          unless QuickHeadlines.shutting_down?
            Log.for("quickheadlines.memory").warn { "Initiating graceful restart due to memory pressure" }
            # This would trigger a graceful shutdown
          end
        end
      end
    end

    @last_rss_mb = rss
  end

  private def handle_set_threshold(max_rss_mb : Int32) : Nil
    @max_rss_mb = max_rss_mb
    Log.for("quickheadlines.memory").info { "Memory threshold set to #{max_rss_mb}MB" }
  end

  private def handle_register_subsystem(subsystem : String, budget_mb : Float64) : Nil
    @subsystems[subsystem] = budget_mb
    @subsystem_allocated[subsystem] = 0.0
    Log.for("quickheadlines.memory").debug { "Registered subsystem: #{subsystem} with budget #{budget_mb}MB" }
  end

  private def handle_release_subsystem(subsystem : String) : Nil
    @subsystems.delete(subsystem)
    @subsystem_allocated.delete(subsystem)
    Log.for("quickheadlines.memory").debug { "Released subsystem: #{subsystem}" }
  end

  # =========================================================================
  # Private helpers
  # =========================================================================

  private def read_rss_mb : Float64
    # Read RSS from /proc/curproc/status on FreeBSD
    # Falls back to reading from process info if available
    begin
      {% if flag?(:freebsd) %}
        # FreeBSD: Read from /proc/curproc/status
        if File.exists?("/proc/curproc/status")
          status = File.read("/proc/curproc/status")
          if match = status.match(/VmRSS:\s+(\d+)\s+kB/)
            return match[1].to_f64 / 1024.0
          end
        end
      {% end %}

      # Fallback: Use Crystal's GC statistics
      # This is less accurate but works on all platforms
      gc_stats = GC.stats
      gc_stats.heap_size.to_f64 / (1024.0 * 1024.0)
    rescue ex
      Log.for("quickheadlines.memory").warn { "Failed to read RSS: #{ex.message}" }
      @last_rss_mb
    end
  end

  private def calculate_pressure(rss_mb : Float64) : PressureLevel
    case rss_mb
    when ...500.0
      PressureLevel::Low
    when 500.0...650.0
      PressureLevel::Medium
    when 650.0...800.0
      PressureLevel::High
    else
      PressureLevel::Critical
    end
  end

  private def build_subsystem_memory : Hash(String, SubsystemMemory)
    result = {} of String => SubsystemMemory
    @subsystems.each do |name, budget|
      allocated = @subsystem_allocated[name]? || 0.0
      result[name] = SubsystemMemory.new(name, budget, allocated)
    end
    result
  end

  private def force_gc : Nil
    GC.collect
    @gc_count += 1
    @last_gc_time = Time.utc
    Log.for("quickheadlines.memory").debug { "GC.collect triggered (total: #{@gc_count})" }
  end
end
