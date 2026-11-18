require "log"

# Reads the process's real resident set size (RSS).
#
# GC.stats only covers Crystal's GC heap; memory malloc'd by C libraries
# (libxml2, SQLite, OpenSSL) is invisible there. To tell a GC-heap leak from a
# native-memory leak we need actual RSS, which is platform-specific:
#
# - Linux:   VmRSS from /proc/self/status
# - FreeBSD: `ps -o rss= -p <pid>` (procfs is usually not mounted, especially
#            in jails, and its status format has no VmRSS; `ps` avoids
#            depending on the per-arch `kinfo_proc` struct layout)
# - Fallback: GC heap size, reported with source "gc_heap" so logs make it
#             clear the number is NOT real RSS.
module RssReader
  # Cache briefly so frequent pressure checks don't spawn `ps` repeatedly.
  CACHE_TTL = 5.seconds

  @@mutex = Mutex.new(:unchecked)
  @@cached : {Float64, String}? = nil
  @@cached_at : Time::Instant? = nil

  # Returns {rss_mb, source}.
  def self.read : {Float64, String}
    @@mutex.synchronize do
      if (c = @@cached) && (at = @@cached_at) && (Time.instant - at) < CACHE_TTL
        return c
      end
      value = read_uncached
      @@cached = value
      @@cached_at = Time.instant
      value
    end
  end

  def self.read_uncached : {Float64, String}
    {% if flag?(:linux) %}
      if mb = read_linux_proc
        return {mb, "proc"}
      end
    {% elsif flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) || flag?(:darwin) %}
      if mb = read_ps
        return {mb, "ps"}
      end
    {% end %}
    {GC.stats.heap_size.to_f64 / (1024.0 * 1024.0), "gc_heap"}
  end

  def self.read_linux_proc : Float64?
    File.each_line("/proc/self/status") do |line|
      if line.starts_with?("VmRSS:")
        if kb = line.split[1]?.try(&.to_f64?)
          return kb / 1024.0
        end
      end
    end
    nil
  rescue ex
    Log.for("quickheadlines.memory").debug { "RssReader: /proc read failed: #{ex.message}" }
    nil
  end

  def self.read_ps : Float64?
    output = IO::Memory.new
    status = Process.run("ps", ["-o", "rss=", "-p", Process.pid.to_s], output: output, error: Process::Redirect::Close)
    return unless status.success?
    kb = output.to_s.strip.to_f64?
    kb ? kb / 1024.0 : nil
  rescue ex
    Log.for("quickheadlines.memory").debug { "RssReader: ps failed: #{ex.message}" }
    nil
  end
end
