# Garbage collection triggers for the refresh loop.
#
# Tracks when GC was last run and forces periodic compaction to
# reclaim fragmented memory. Called by `RefreshLoop.refresh_all`
# after each refresh cycle, and by the supervisor on memory pressure signals.
module RefreshLoop::GCCollector
  lib LibGC
    fun GC_set_force_unmap_on_gcollect(value : LibC::Int)
    fun GC_gcollect_and_unmap : Void
    fun GC_expand_hp(bytes : LibC::SizeT) : Void
    fun GC_set_free_space_divisor(divisor : LibC::Int)
  end

  @@last_gc_collect = Time.utc
  @@last_compaction = Time.utc
  @@gc_runs : Int32 = 0

  # Enable forced unmap on every GC collect.
  # This is critical — without it, freed pages are never returned to the OS.
  def self.enable_force_unmap : Nil
    LibGC.GC_set_force_unmap_on_gcollect(1)
    Log.for("quickheadlines.gc").info { "GC force_unmap enabled" }
  end

  def self.set_free_space_divisor(divisor : Int32) : Nil
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

  # Called after every refresh cycle. Runs normal GC + periodic compaction.
  def self.collect_now : Nil
    GC.collect
    @@last_gc_collect = Time.utc
    @@gc_runs += 1
    Log.for("quickheadlines.gc").debug { "Forced GC.collect after refresh cycle (run #{@@gc_runs})" }

    # Compaction: every 10 cycles (~5 hours at 30min intervals), force the
    # GC to relocate live objects to fewer pages and unmap the rest.
    # Without this, Boehm GC keeps freed pages mapped because live objects
    # are scattered across them (fragmentation).
    if @@gc_runs % 10 == 0
      compact_heap
    end
  end

  # Force heap compaction: expand, collect, unmap.
  # This relocates live objects to new pages and frees old pages back to OS.
  private def self.compact_heap : Nil
    before = GC.stats
    Log.for("quickheadlines.gc").info do
      "Compaction starting: heap=#{(before.heap_size / 1024 / 1024).round(1)}MB, " \
      "free=#{(before.free_bytes / 1024 / 1024).round(1)}MB, " \
      "unmapped=#{(before.unmapped_bytes / 1024 / 1024).round(1)}MB"
    end

    # Expand heap to give GC room to relocate live objects
    LibGC.GC_expand_hp(128_u64 * 1024_u64 * 1024_u64)

    # Multiple collection passes to fully relocate
    3.times { GC.collect }
    LibGC.GC_gcollect_and_unmap

    after = GC.stats
    @@last_compaction = Time.utc

    Log.for("quickheadlines.gc").info do
      "Compaction done: heap=#{(after.heap_size / 1024 / 1024).round(1)}MB, " \
      "free=#{(after.free_bytes / 1024 / 1024).round(1)}MB, " \
      "unmapped=#{(after.unmapped_bytes / 1024 / 1024).round(1)}MB, " \
      "freed=#{((before.heap_size - after.heap_size + before.unmapped_bytes - after.unmapped_bytes) / 1024 / 1024).round(1)}MB"
    end
  end

  def self.stats : String
    "gc_runs=#{@@gc_runs}, last_collect=#{@@last_gc_collect}, last_compaction=#{@@last_compaction}"
  end
end
