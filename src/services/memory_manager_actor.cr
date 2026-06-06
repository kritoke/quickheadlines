require "../infrastructure/actor"

# MemoryManagerActor - Consolidated memory monitoring, GC coordination, and cleanup
#
# Combines MemoryMonitorActor + CleanupCoordinatorActor into one actor
# to reduce macro expansion and compilation overhead.
#
# Usage:
#   MemoryManagerActor.instance.get_rss_mb
#   MemoryManagerActor.instance.check_and_gc
#   MemoryManagerActor.instance.get_memory_status
#   MemoryManagerActor.instance.request_cleanup(CleanupPriority::Normal)
#
class MemoryManagerActor < Actor
  # =========================================================================
  # Types
  # =========================================================================

  struct MemoryStatus
    getter rss_mb : Float64
    getter pressure_level : PressureLevel
    getter last_gc_time : Time?
    getter gc_count : Int32

    def initialize(@rss_mb, @pressure_level, @last_gc_time, @gc_count)
    end

    def to_json : String
      JSON.build do |json|
        json.object do
          json.field "rss_mb", @rss_mb
          json.field "pressure_level", @pressure_level.value
          json.field "last_gc_time", @last_gc_time.try(&.to_unix_ms)
          json.field "gc_count", @gc_count
        end
      end
    end

    def self.from_json(json_str : String) : MemoryStatus
      parser = JSON::Parser.new(json_str)
      obj = parser.parse.as_h
      MemoryStatus.new(
        rss_mb: obj["rss_mb"].as_f,
        pressure_level: PressureLevel.new(obj["pressure_level"].as_i),
        last_gc_time: obj["last_gc_time"]?.try { |v| Time.unix_ms(v.as_i64) },
        gc_count: obj["gc_count"].as_i
      )
    end
  end

  enum PressureLevel
    Low      # RSS < 500MB
    Medium   # RSS 500-650MB
    High     # RSS 650-800MB
    Critical # RSS > 800MB
  end

  enum CleanupPriority
    Normal     # Clean caches, expire old entries
    Aggressive # Reduce retention, force GC
    Emergency  # Drop non-essential data, trigger restart
  end

  struct CleanupStatus
    getter last_cleanup_time : Time?
    getter cleanup_count : Int32
    getter handlers_count : Int32
    getter last_priority : CleanupPriority?

    def initialize(@last_cleanup_time, @cleanup_count, @handlers_count, @last_priority)
    end

    def to_json : String
      JSON.build do |json|
        json.object do
          json.field "last_cleanup_time", @last_cleanup_time.try(&.to_unix_ms)
          json.field "cleanup_count", @cleanup_count
          json.field "handlers_count", @handlers_count
          json.field "last_priority", @last_priority.try(&.value)
        end
      end
    end

    def self.from_json(json_str : String) : CleanupStatus
      parser = JSON::Parser.new(json_str)
      obj = parser.parse.as_h
      CleanupStatus.new(
        last_cleanup_time: obj["last_cleanup_time"]?.try { |v| Time.unix_ms(v.as_i64) },
        cleanup_count: obj["cleanup_count"].as_i,
        handlers_count: obj["handlers_count"].as_i,
        last_priority: obj["last_priority"]?.try { |v| CleanupPriority.new(v.as_i) }
      )
    end
  end

  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call get_rss_mb, Float64
  def_call get_memory_status, MemoryStatus
  def_call get_cleanup_status, CleanupStatus

  # Cast messages (fire-and-forget)
  def_cast check_and_gc
  def_cast set_threshold(max_rss_mb : Int32)
  def_cast request_cleanup(priority : CleanupPriority)
  def_cast register_cleanup_handler(name : String, handler : -> Nil)
  def_cast unregister_cleanup_handler(name : String)

  # =========================================================================
  # Actor state
  # =========================================================================

  # Monitor state
  @max_rss_mb : Int32 = 750
  @last_rss_mb : Float64 = 0.0
  @consecutive_high : Int32 = 0
  @gc_count : Int32 = 0
  @last_gc_time : Time? = nil

  # Cleanup state
  @cleanup_handlers : Hash(String, -> Nil) = {} of String => (-> Nil)
  @last_cleanup_time : Time? = nil
  @cleanup_count : Int32 = 0
  @last_priority : CleanupPriority? = nil
  @is_cleaning_up : Bool = false

  def initialize(@name : String = "MemoryManager")
    super(@name, mailbox_size: 100)
  end

  # Singleton access
  @@instance : MemoryManagerActor?
  @@instance_mutex = Mutex.new

  def self.instance : MemoryManagerActor
    @@instance_mutex.synchronize do
      @@instance ||= MemoryManagerActor.new.tap(&.start)
    end
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallGetRssMb                 then message.deliver_reply_json(handle_get_rss_mb.to_json)
    when CallGetMemoryStatus          then message.deliver_reply_json(handle_get_memory_status.to_json)
    when CallGetCleanupStatus         then message.deliver_reply_json(handle_get_cleanup_status.to_json)
    when CastCheckAndGc               then handle_check_and_gc
    when CastSetThreshold             then handle_set_threshold(message.max_rss_mb)
    when CastRequestCleanup           then handle_request_cleanup(message.priority)
    when CastRegisterCleanupHandler   then handle_register_cleanup_handler(message.name, message.handler)
    when CastUnregisterCleanupHandler then handle_unregister_cleanup_handler(message.name)
    else                                   raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Monitor handlers
  # =========================================================================

  private def handle_get_rss_mb : Float64
    read_rss_mb
  end

  private def handle_get_memory_status : MemoryStatus
    rss = read_rss_mb
    pressure = calculate_pressure(rss)
    MemoryStatus.new(rss, pressure, @last_gc_time, @gc_count)
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
        spawn do
          sleep(5.seconds)
          unless QuickHeadlines.shutting_down?
            Log.for("quickheadlines.memory").warn { "Initiating graceful restart due to memory pressure" }
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

  # =========================================================================
  # Cleanup handlers
  # =========================================================================

  private def handle_get_cleanup_status : CleanupStatus
    CleanupStatus.new(@last_cleanup_time, @cleanup_count, @cleanup_handlers.size, @last_priority)
  end

  private def handle_request_cleanup(priority : CleanupPriority) : Nil
    if @is_cleaning_up
      Log.for("quickheadlines.cleanup").warn { "Cleanup already in progress, skipping (priority: #{priority})" }
      return
    end

    @is_cleaning_up = true
    @last_priority = priority

    Log.for("quickheadlines.cleanup").info { "Starting cleanup with priority: #{priority}" }

    begin
      case priority
      when .normal?
        run_normal_cleanup
      when .aggressive?
        run_aggressive_cleanup
      when .emergency?
        run_emergency_cleanup
      end

      @last_cleanup_time = Time.utc
      @cleanup_count += 1
      Log.for("quickheadlines.cleanup").info { "Cleanup completed (total: #{@cleanup_count})" }
    rescue ex
      Log.for("quickheadlines.cleanup").error(exception: ex) { "Cleanup failed" }
    ensure
      @is_cleaning_up = false
    end
  end

  private def handle_register_cleanup_handler(name : String, handler : -> Nil) : Nil
    @cleanup_handlers[name] = handler
    Log.for("quickheadlines.cleanup").debug { "Registered cleanup handler: #{name}" }
  end

  private def handle_unregister_cleanup_handler(name : String) : Nil
    @cleanup_handlers.delete(name)
    Log.for("quickheadlines.cleanup").debug { "Unregistered cleanup handler: #{name}" }
  end

  # =========================================================================
  # Cleanup strategies
  # =========================================================================

  private def run_normal_cleanup : Nil
    @cleanup_handlers.each do |name, handler|
      begin
        handler.call
        Log.for("quickheadlines.cleanup").debug { "Normal cleanup: #{name} completed" }
      rescue ex
        Log.for("quickheadlines.cleanup").error(exception: ex) { "Normal cleanup: #{name} failed" }
      end
    end

    # Clear Vug favicon cache to prevent unbounded growth
    begin
      VugAdapter.clear_cache
      Log.for("quickheadlines.cleanup").debug { "Cleared Vug cache" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear Vug cache: #{ex.message}" }
    end

    GC.collect
    Log.for("quickheadlines.cleanup").debug { "GC.collect triggered after normal cleanup" }
  end

  private def run_aggressive_cleanup : Nil
    @cleanup_handlers.each do |name, handler|
      begin
        handler.call
        Log.for("quickheadlines.cleanup").debug { "Aggressive cleanup: #{name} completed" }
      rescue ex
        Log.for("quickheadlines.cleanup").error(exception: ex) { "Aggressive cleanup: #{name} failed" }
      end
    end

    begin
      VugAdapter.clear_cache
      Log.for("quickheadlines.cleanup").debug { "Cleared Vug cache" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear Vug cache: #{ex.message}" }
    end

    begin
      Fetcher::CrestHttpClient.clear_expired_dns
      Fetcher::CrestHttpClient.clear_rate_limiters
      Fetcher::URLValidator.clear_validated
      Fetcher::CircuitBreaker::Registry.store.clear_expired
      ColorExtractor.sweep_cache
      QuickHeadlines::StringIntern.clear
      Log.for("quickheadlines.cleanup").debug { "Cleared expired caches and string pool" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear expired caches: #{ex.message}" }
    end

    GC.collect
    Log.for("quickheadlines.cleanup").debug { "GC.collect triggered after aggressive cleanup" }
  end

  private def run_emergency_cleanup : Nil
    Log.for("quickheadlines.cleanup").error { "Emergency cleanup initiated" }

    @cleanup_handlers.each do |name, handler|
      begin
        handler.call
        Log.for("quickheadlines.cleanup").debug { "Emergency cleanup: #{name} completed" }
      rescue ex
        Log.for("quickheadlines.cleanup").error(exception: ex) { "Emergency cleanup: #{name} failed" }
      end
    end

    begin
      VugAdapter.clear_cache
      Fetcher::CrestHttpClient.clear_expired_dns
      Fetcher::CrestHttpClient.clear_rate_limiters
      Fetcher::URLValidator.clear_validated
      Fetcher::CircuitBreaker::Registry.store.clear_expired
      ColorExtractor.sweep_cache
      Log.for("quickheadlines.cleanup").debug { "Cleared all caches" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear all caches: #{ex.message}" }
    end

    3.times do
      GC.collect
      sleep(100.milliseconds)
    end
    Log.for("quickheadlines.cleanup").debug { "Forced GC.collect 3 times after emergency cleanup" }
  end

  # =========================================================================
  # Private helpers
  # =========================================================================

  private def read_rss_mb : Float64
    {% if flag?(:freebsd) %}
      if File.exists?("/proc/curproc/status")
        status = File.read("/proc/curproc/status")
        if match = status.match(/VmRSS:\s+(\d+)\s+kB/)
          return match[1].to_f64 / 1024.0
        end
      end
    {% end %}

    gc_stats = GC.stats
    gc_stats.heap_size.to_f64 / (1024.0 * 1024.0)
  rescue ex
    Log.for("quickheadlines.memory").warn { "Failed to read RSS: #{ex.message}" }
    @last_rss_mb
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

  private def force_gc : Nil
    GC.collect
    @gc_count += 1
    @last_gc_time = Time.utc
    Log.for("quickheadlines.memory").debug { "GC.collect triggered (total: #{@gc_count})" }
  end
end
