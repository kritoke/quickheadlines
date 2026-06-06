# Garbage collection triggers for the refresh loop.
#
# Tracks when GC was last run and forces a periodic full collection
# to defragment memory. Called by `RefreshLoop.refresh_all` after each
# refresh cycle, and by the supervisor on memory pressure signals.
module RefreshLoop::GCCollector
  @@last_gc_collect = Time.utc
  @@last_full_collection = Time.utc
  @@gc_runs : Int32 = 0

  def self.maybe_collect : Nil
    now = Time.utc
    if now - @@last_gc_collect >= 5.minutes
      GC.collect
      @@last_gc_collect = now
      @@gc_runs += 1
      Log.for("quickheadlines.gc").debug { "Triggered GC.collect (run #{@@gc_runs})" }

      # Every 2 hours, run full collection to reclaim memory
      if now - @@last_full_collection >= 2.hours
        Log.for("quickheadlines.gc").info { "Running GC.full collection to defragment memory" }
        GC.collect
        GC.collect # Second pass for deeper cleanup
        @@last_full_collection = now
        Log.for("quickheadlines.gc").info { "GC.full collection complete" }
      end
    end
  end

  def self.collect_now : Nil
    GC.collect
    @@last_gc_collect = Time.utc
    @@gc_runs += 1
    Log.for("quickheadlines.gc").debug { "Forced GC.collect after refresh cycle (run #{@@gc_runs})" }

    # Force full collection every 50 cycles
    if @@gc_runs % 50 == 0
      Log.for("quickheadlines.gc").info { "Running periodic GC.full collection (every 50 cycles)" }
      GC.collect
      GC.collect # Second pass
      @@last_full_collection = Time.utc
    end
  end

  def self.stats : String
    "gc_runs=#{@@gc_runs}, last_collect=#{@@last_gc_collect}, last_full_collection=#{@@last_full_collection}"
  end
end
