require "./utils"

module FaviconCache
  MAX_ENTRIES = 200

  # NOTE: Uses :unchecked mutex to avoid Boehm GC mutex initialization
  # deadlocks on FreeBSD. See AGENTS.md for details.
  @@mutex = Mutex.new(:unchecked)
  @@cache = {} of String => String
  @@access_order = [] of String

  def self.get(key : String) : String?
    @@mutex.synchronize do
      if data = @@cache[key]?
        @@access_order.delete(key)
        @@access_order << key
        data
      end
    end
  end

  def self.put(key : String, data : String) : Nil
    @@mutex.synchronize do
      if @@cache.has_key?(key)
        @@access_order.delete(key)
        @@access_order << key
        @@cache[key] = data
      else
        if @@cache.size >= MAX_ENTRIES
          evict
        end
        @@cache[key] = data
        @@access_order << key
      end
    end
  end

  def self.size : Int32
    @@mutex.synchronize { @@cache.size }
  end

  def self.clear : Nil
    @@mutex.synchronize do
      @@cache.clear
      @@access_order.clear
    end
  end

  private def self.evict
    return if @@access_order.empty?
    oldest = @@access_order.shift
    @@cache.delete(oldest)
  end
end
