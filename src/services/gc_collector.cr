# Garbage collection triggers for the refresh loop.
#
# Runs a plain `GC.collect` after each refresh cycle. We intentionally do NOT
# use `GC_gcollect_and_unmap`, heap compaction, or `force_unmap`: returning
# freed pages to the OS races with C-library finalizers (libxml2, sqlite3) on
# Boehm GC and caused a segfault during the finalization cycle
# ("GC Warning: Finalization cycle involving (???)" was the last log before
# the crash). Plain GC.collect reclaims dead objects within the heap without
# unmapping pages, so RSS plateaus at the high-water mark instead of
# shrinking — we trade memory reclamation for process stability.
#
# Called by `RefreshLoop.refresh_all` after each refresh cycle, and by the
# supervisor on memory-pressure signals.
module RefreshLoop::GCCollector
  lib LibGC
    fun GC_set_free_space_divisor(divisor : LibC::Int)
  end

  @@last_gc_collect = Time.utc
  @@gc_runs : Int32 = 0

  def self.free_space_divisor=(divisor : Int32) : Nil
    LibGC.GC_set_free_space_divisor(divisor)
  end

  def self.maybe_collect : Nil
    now = Time.utc
    if now - @@last_gc_collect >= 5.minutes
      GC.collect
      @@last_gc_collect = now
      @@gc_runs += 1
      Log.for("quickheadlines.gc").debug { "Triggered GC.collect (run #{@@gc_runs})" }
    end
  end

  # Called after every refresh cycle. Plain GC.collect only — see module docs
  # for why unmap/compaction are avoided.
  def self.collect_now : Nil
    GC.collect
    @@last_gc_collect = Time.utc
    @@gc_runs += 1
    stats = GC.stats
    total_mb = stats.total_bytes / (1024 * 1024)
    heap_mb = stats.heap_size / (1024 * 1024)
    unmapped_mb = stats.unmapped_bytes / (1024 * 1024)
    Log.for("quickheadlines.gc").debug { "GC after refresh (run #{@@gc_runs}): total=#{total_mb.round(1)}MB, heap=#{heap_mb.round(1)}MB, unmapped=#{unmapped_mb.round(1)}MB" }
  end

  def self.stats : String
    "gc_runs=#{@@gc_runs}, last_collect=#{@@last_gc_collect}"
  end
end
