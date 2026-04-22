module FaviconCache
  MAX_ENTRIES = 200

  @@mutex = Mutex.new(:unchecked)
  @@cache = {} of String => String
  @@access_order = [] of String

  def self.get(key : String) : String?
    @@mutex.synchronize do
      if data = @@cache[key]?
        @@access_order.delete(key)
        @@access_order << key
        data
      else
        nil
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
    @@cache.size
  end

  def self.clear : Nil
    @@mutex.synchronize do
      @@cache.clear
      @@access_order.clear
    end
  end

  def self.warm_from_dir(dir : String) : Int32
    count = 0
    if Dir.exists?(dir)
      Dir.each_child(dir) do |filename|
        filepath = File.join(dir, filename)
        if File.file?(filepath)
          begin
            data = File.read(filepath)
            @@mutex.synchronize do
              if @@cache.size >= MAX_ENTRIES
                evict
              end
              @@cache[filename] = data
              @@access_order << filename
            end
            count += 1
          rescue ex
            Log.for("quickheadlines.cache").warn(exception: ex) { "Failed to warm favicon cache: #{filename}" }
          end
        end
      end
    end
    count
  end

  private def self.evict
    return if @@access_order.empty?
    oldest = @@access_order.shift
    @@cache.delete(oldest)
  end
end
