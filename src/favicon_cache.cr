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

  def self.warm_from_dir(dir : String) : Int32
    count = 0
    # Resolve the base directory to its canonical path to prevent path traversal
    # via symlinks (e.g., "../../../etc/passwd" attacks)
    base_dir = File.expand_path(dir)

    if Dir.exists?(base_dir)
      Dir.each_child(base_dir) do |filename|
        next if filename.starts_with?('.') # Skip hidden files

        filepath = File.join(base_dir, filename)

        # Security: Resolve symlinks and verify the file is still within base_dir
        # This prevents reading files outside the intended cache directory
        begin
          real_path = File.expand_path(filepath)
          unless real_path.starts_with?(base_dir)
            Log.for("quickheadlines.cache").warn { "Skipped path traversal attempt: #{filename}" }
            next
          end
        rescue ex
          Log.for("quickheadlines.cache").warn(exception: ex) { "Failed to resolve path: #{filename}" }
          next
        end

        if File.file?(real_path)
          begin
            data = File.read(real_path)
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
