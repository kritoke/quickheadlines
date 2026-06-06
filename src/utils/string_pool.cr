require "mutex"

# Thread-safe string interning pool.
# Returns the same String reference for identical content,
# reducing memory when the same strings appear across refresh cycles.
module QuickHeadlines::StringIntern
  @@pool = {} of String => String
  @@mutex = Mutex.new

  # Maximum entries before we start evicting.
  # Large enough for typical feed counts (~100 feeds × ~20 items = ~2000 unique strings)
  # but prevents unbounded growth if feeds have highly dynamic content.
  MAX_POOL_SIZE = 10_000

  # Intern a string: return a shared reference for identical content.
  # Nil-safe: returns nil if input is nil.
  def self.intern(str : String?) : String?
    return nil if str.nil?
    return str if str.empty?

    @@mutex.synchronize do
      if existing = @@pool[str]?
        existing
      else
        evict_if_needed
        @@pool[str] = str
        str
      end
    end
  end

  # Clear the pool (useful for testing or memory pressure).
  def self.clear : Nil
    @@mutex.synchronize { @@pool.clear }
  end

  # Current pool size for diagnostics.
  def self.size : Int32
    @@mutex.synchronize { @@pool.size }
  end

  private def self.evict_if_needed : Nil
    if @@pool.size >= MAX_POOL_SIZE
      # Evict oldest half — simple strategy that avoids tracking access order
      keys_to_remove = @@pool.keys.first(MAX_POOL_SIZE // 2)
      keys_to_remove.each { |k| @@pool.delete(k) }
    end
  end
end
