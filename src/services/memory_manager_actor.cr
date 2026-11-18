require "./rss_reader"
require "../infrastructure/actor"
require "../services/fiber_tracker"
require "../favicon_cache"
require "../fetcher/interruptible_sleep"

module QuickHeadlines
  lib LibGC
    fun GC_gcollect_and_unmap : Void
  end
end

# MemoryManagerActor - Consolidated memory monitoring, GC coordination, and cleanup
#
# Combines MemoryMonitorActor + CleanupCoordinatorActor into one actor
# to reduce macro expansion and compilation overhead.
#
# Usage:
#   MemoryManagerActor.instance.get_rss_mb
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

    def initialize(@rss_mb, @pressure_level)
    end

    def to_json : String
      JSON.build do |json|
        json.object do
          json.field "rss_mb", @rss_mb
          json.field "pressure_level", @pressure_level.value
        end
      end
    end

    def self.from_json(json_str : String) : MemoryStatus
      parser = JSON::Parser.new(json_str)
      obj = parser.parse.as_h
      MemoryStatus.new(
        rss_mb: obj["rss_mb"].as_f,
        pressure_level: PressureLevel.new(obj["pressure_level"].as_i)
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

  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call get_rss_mb, Float64
  def_call get_memory_status, MemoryStatus

  # Cast messages (fire-and-forget)
  def_cast request_cleanup(priority : CleanupPriority)

  # =========================================================================
  # Actor state
  # =========================================================================

  @last_rss_mb : Float64 = 0.0

  # Cleanup state
  @last_cleanup_time : Time? = nil
  @cleanup_count : Int32 = 0
  @last_priority : CleanupPriority? = nil
  @is_cleaning_up : Bool = false

  FORCED_GC_INTERVAL = 60.minutes

  def initialize(@name : String = "MemoryManager")
    super(@name, mailbox_size: 100)
  end

  # Class-level accessor — instance must be created and wired by AppBootstrap.
  @@instance : MemoryManagerActor?

  def self.instance : MemoryManagerActor
    @@instance || raise "MemoryManagerActor not initialized. AppBootstrap must create and set MemoryManagerActor.instance=."
  end

  def self.instance=(value : MemoryManagerActor)
    @@instance = value
  end

  def self.reset : Nil
    if inst = @@instance
      inst.shutdown rescue nil
    end
    @@instance = nil
  end

  # Start periodic forced GC timer (call after actor is created)
  def start_periodic_gc : Nil
    RefreshLoop::FiberTracker.tracked_spawn("memory-manager-gc-timer") do
      loop do
        RefreshLoop::InterruptibleSleep.sleep(FORCED_GC_INTERVAL)
        break if QuickHeadlines.shutting_down?

        # Skip if refresh is in progress to avoid clashing
        next if StateStore.refreshing?

        before = GC.stats
        # Plain GC.collect only — GC_gcollect_and_unmap was removed because
        # unmapping pages races with C-library finalizers (libxml2/sqlite)
        # on Boehm GC and caused a segfault during the finalization cycle.
        GC.collect
        after = GC.stats

        before_mb = before.heap_size / (1024 * 1024)
        after_mb = after.heap_size / (1024 * 1024)
        unmapped_mb = after.unmapped_bytes / (1024 * 1024)
        freed = before_mb - after_mb

        Log.for("quickheadlines.gc").info do
          "Periodic GC: heap #{before_mb.round(1)}MB -> #{after_mb.round(1)}MB (freed #{freed.round(1)}MB), unmapped=#{unmapped_mb.round(1)}MB"
        end
      end
    end
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallGetRssMb        then message.deliver_reply_json(handle_get_rss_mb.to_json)
    when CallGetMemoryStatus then message.deliver_reply_json(handle_get_memory_status.to_json)
    when CastRequestCleanup  then handle_request_cleanup(message.priority)
    else                          raise "Unknown message: #{message.class.name}"
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
    MemoryStatus.new(rss, calculate_pressure(rss))
  end

  # Captures a process memory snapshot for offline analysis.
  #
  # Crystal's GC module (Boehm) does not expose a `dump_heap_to`
  # function, so we cannot write a full heap dump from inside the
  # process. Instead, we capture what we CAN get from /proc/<pid>:
  #
  # - /proc/<pid>/{maps,smaps,smaps_rollup,status,cmdline,stat,statm,io,limits}
  # - Crystal's GC.stats (heap_size, free_bytes, total_bytes)
  # - Live fiber counts from RefreshLoop::FiberTracker
  # - RSS as read by RssReader
  #
  # These tell us:
  # - Whether the heap grew (GC.stats.heap_size vs VmData)
  # - Where the RSS lives (anonymous heap pages vs file-backed mmap)
  # - Which VMAs are biggest (might catch a runaway mmap)
  #
  # If `deep` is true, also runs `gcore` to write a full process
  # core dump. That file is multi-GB and invasive (brief pause)
  # but is the gold-standard for offline heap analysis with gdb.
  #
  # Runs in the caller's fiber, NOT through the actor mailbox, so a slow
  # `gcore` never blocks other callers of get_memory_status.
  def dump_heap(deep : Bool) : String
    timestamp = Time.utc.to_s("%Y%m%dT%H%M%S")
    dir = "/tmp/qh-snap-#{timestamp}"
    Dir.mkdir_p(dir)
    pid = Process.pid

    safe_proc_read(pid, "maps", "#{dir}/proc-maps.txt")
    safe_proc_read(pid, "smaps", "#{dir}/proc-smaps.txt")
    safe_proc_read(pid, "smaps_rollup", "#{dir}/proc-smaps-rollup.txt")
    safe_proc_read(pid, "status", "#{dir}/proc-status.txt")
    safe_proc_read(pid, "cmdline", "#{dir}/proc-cmdline.txt")
    safe_proc_read(pid, "stat", "#{dir}/proc-stat.txt")
    safe_proc_read(pid, "statm", "#{dir}/proc-statm.txt")
    safe_proc_read(pid, "io", "#{dir}/proc-io.txt")
    safe_proc_read(pid, "limits", "#{dir}/proc-limits.txt")

    File.write("#{dir}/crystal-gc-stats.txt", GC.stats.inspect)
    File.write("#{dir}/crystal-fibers.txt", RefreshLoop::FiberTracker.stats.inspect)
    rss, src = RssReader.read
    File.write("#{dir}/rss.txt", "#{rss.round(1)}MB (src=#{src})")

    if deep
      core_path = "#{dir}/core"
      Log.for("quickheadlines.memory").warn do
        "Deep heap dump requested: gcore will pause the process briefly"
      end
      Process.run("gcore", ["#{pid}", core_path])
      if File.exists?(core_path)
        size_mb = File.info(core_path).size.to_f64 / 1024 / 1024
        Log.for("quickheadlines.memory").info do
          "Core dump written: #{core_path} (#{size_mb.round(1)}MB)"
        end
      end
    end

    dir
  end

  # Best-effort /proc read: copies `<proc>/<file>` to `dest`. Errors
  # are logged but don't fail the dump.
  private def safe_proc_read(pid : Int64, file : String, dest : String) : Nil
    content = File.read("/proc/#{pid}/#{file}")
    File.write(dest, content)
  rescue ex : Exception
    # /proc fields are not always readable (e.g., /proc/<pid>/io
    # requires CAP_SYS_PTRACE on some kernels). Log and continue.
    Log.for("quickheadlines.memory").debug do
      "Could not read /proc/#{pid}/#{file}: #{ex.message}"
    end
  end

  # =========================================================================
  # Cleanup handlers
  # =========================================================================

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

  # =========================================================================
  # Cleanup strategies
  # =========================================================================

  private def run_normal_cleanup : Nil
    clear_system_caches(:normal)
    GC.collect
    Log.for("quickheadlines.cleanup").debug { "GC.collect triggered after normal cleanup" }
  end

  private def run_aggressive_cleanup : Nil
    clear_system_caches(:aggressive)
    GC.collect
    Log.for("quickheadlines.cleanup").debug { "GC.collect triggered after aggressive cleanup" }
  end

  private def run_emergency_cleanup : Nil
    Log.for("quickheadlines.cleanup").error { "Emergency cleanup initiated" }
    clear_system_caches(:emergency)
    3.times do
      GC.collect
      sleep(100.milliseconds)
    end
    Log.for("quickheadlines.cleanup").debug { "Forced GC.collect 3 times after emergency cleanup" }
  end

  # Clear system-level caches based on cleanup severity.
  # Normal: only Vug favicon cache.
  # Aggressive/Emergency: all HTTP, DNS, rate limiter, circuit breaker, color, and string caches.
  def clear_system_caches(level : Symbol) : Nil
    begin
      VugAdapter.clear_cache
      Log.for("quickheadlines.cleanup").debug { "Cleared Vug cache" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear Vug cache: #{ex.message}" }
    end

    return if level == :normal

    begin
      Fetcher::DnsCache.clear_expired
      Fetcher::CrestHttpClient.clear_rate_limiters
      Fetcher::URLValidator.clear_validated
      Fetcher::CircuitBreaker::Registry.store.clear_expired
      ColorExtractor.sweep_cache
      QuickHeadlines::StringIntern.clear
      FaviconActor.instance.close_pooled_clients
      FaviconCache.clear
      Log.for("quickheadlines.cleanup").debug { "Cleared all system caches" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear system caches: #{ex.message}" }
    end
  end

  # =========================================================================
  # Private helpers
  # =========================================================================

  private def read_rss_mb : Float64
    RssReader.read[0]
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
end
