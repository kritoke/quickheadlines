require "./rss_reader"
require "../services/fiber_tracker"
require "../favicon_cache"

# MemoryManager - RSS reading, periodic cache clearing, and diagnostic
# memory snapshots. Plain module: none of this needs actor serialisation.
module MemoryManager
  # Current RSS in MB (cached ~5s by RssReader). Returns 0.0 if unreadable.
  def self.rss_mb : Float64
    RssReader.read[0]
  rescue ex
    Log.for("quickheadlines.memory").warn { "Failed to read RSS: #{ex.message}" }
    0.0
  end

  # Clears process-level caches. Run on a fixed interval by TaskScheduler.
  def self.clear_caches : Nil
    {
      "vug"             => -> { VugAdapter.clear_cache },
      "dns"             => -> { Fetcher::DnsCache.clear_expired },
      "rate_limiters"   => -> { Fetcher::CrestHttpClient.clear_rate_limiters },
      "url_validator"   => -> { Fetcher::URLValidator.clear_validated },
      "circuit_breaker" => -> { Fetcher::CircuitBreaker::Registry.store.clear_expired },
      "color"           => -> { ColorExtractor.sweep_cache },
      "string_intern"   => -> { QuickHeadlines::StringIntern.clear },
      "favicon_clients" => -> { FaviconActor.instance.close_pooled_clients },
      "favicon_cache"   => -> { FaviconCache.clear },
    }.each do |name, clear|
      clear.call
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear #{name} cache: #{ex.message}" }
    end
    Log.for("quickheadlines.cleanup").debug { "Cleared system caches" }
  end

  # Captures a process memory snapshot for offline analysis.
  #
  # Boehm does not expose a heap dump, so we capture what we can get from
  # /proc/<pid> (Linux) plus GC.stats, fiber counts and RSS. With `deep`,
  # also runs `gcore` for a full core dump (multi-GB, pauses the process).
  # Runs in the caller's fiber.
  def self.dump_heap(deep : Bool) : String
    timestamp = Time.utc.to_s("%Y%m%dT%H%M%S")
    dir = "/tmp/qh-snap-#{timestamp}"
    Dir.mkdir_p(dir)
    pid = Process.pid

    %w[maps smaps smaps_rollup status cmdline stat statm io limits].each do |file|
      safe_proc_read(pid, file, "#{dir}/proc-#{file.gsub('_', '-')}.txt")
    end

    File.write("#{dir}/crystal-gc-stats.txt", GC.stats.inspect)
    File.write("#{dir}/crystal-fibers.txt", RefreshLoop::FiberTracker.stats.inspect)
    rss, src = RssReader.read
    File.write("#{dir}/rss.txt", "#{rss.round(1)}MB (src=#{src})")

    if deep
      core_path = "#{dir}/core"
      Log.for("quickheadlines.memory").warn { "Deep heap dump requested: gcore will pause the process briefly" }
      Process.run("gcore", ["#{pid}", core_path])
      if File.exists?(core_path)
        size_mb = File.info(core_path).size.to_f64 / 1024 / 1024
        Log.for("quickheadlines.memory").info { "Core dump written: #{core_path} (#{size_mb.round(1)}MB)" }
      end
    end

    dir
  end

  # Best-effort /proc read; errors are logged but don't fail the dump.
  private def self.safe_proc_read(pid : Int64, file : String, dest : String) : Nil
    File.write(dest, File.read("/proc/#{pid}/#{file}"))
  rescue ex : Exception
    Log.for("quickheadlines.memory").debug { "Could not read /proc/#{pid}/#{file}: #{ex.message}" }
  end
end
