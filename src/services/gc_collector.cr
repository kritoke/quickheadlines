# The single explicit garbage-collection point.
#
# `collect_now` runs once per refresh cycle (after it completes or times out).
# Plain `GC.collect` only: `GC_gcollect_and_unmap`, compaction and
# `force_unmap` return pages to the OS but race with C-library finalizers
# (libxml2, sqlite3) on Boehm and caused segfaults. RSS therefore plateaus at
# its high-water mark rather than shrinking.
module RefreshLoop::GCCollector
  lib LibGC
    fun GC_set_free_space_divisor(divisor : LibC::Int)
  end

  def self.free_space_divisor=(divisor : Int32) : Nil
    LibGC.GC_set_free_space_divisor(divisor)
  end

  def self.collect_now : Nil
    GC.collect
    stats = GC.stats
    Log.for("quickheadlines.gc").debug do
      "GC after refresh: heap=#{(stats.heap_size / 1024 / 1024).round(1)}MB, " \
      "free=#{(stats.free_bytes / 1024 / 1024).round(1)}MB"
    end
  end
end
