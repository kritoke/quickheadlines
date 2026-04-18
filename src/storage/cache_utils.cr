require "db"
require "sqlite3"
require "file_utils"
require "time"
require "../config"
require "../constants"

module QuickHeadlines::CacheUtils
  def self.cache_fresh?(last_fetched : Time, max_age_minutes : Int32 = 10) : Bool
    (Time.utc - last_fetched).total_minutes < max_age_minutes
  end
end

def get_cache_dir(config : Config?) : String
  if env = ENV["QUICKHEADLINES_CACHE_DIR"]?
    return env
  end

  if config && (cache = config.cache_dir)
    return cache
  end

  # Platform-specific defaults
  # FreeBSD: /var/cache/quickheadlines
  # Linux: /var/cache/quickheadlines (if /var/cache exists and is writable)
  # macOS: ~/Library/Caches/quickheadlines
  # Fallback: XDG or ~/.cache/quickheadlines
  if Dir.exists?("/var/cache")
    begin
      test_dir = "/var/cache/quickheadlines_test_#{Process.pid}"
      Dir.mkdir_p(test_dir)
      File.delete(test_dir)
      return "/var/cache/quickheadlines"
    rescue File::Error
      # Not writable, fall through to other options
    end
  end

  if xdg = ENV["XDG_CACHE_HOME"]?
    return File.join(xdg, "quickheadlines")
  end

  if home = ENV["HOME"]?
    # Check for macOS ~/Library/Caches
    if home.includes?("/Users/") && Dir.exists?(File.join(home, "Library", "Caches"))
      return File.join(home, "Library", "Caches", "quickheadlines")
    end
    return File.join(home, ".cache", "quickheadlines")
  end

  "cache"
end

def get_cache_db_path(config : Config?) : String
  File.join(get_cache_dir(config), "feed_cache.db")
end

def normalize_feed_url(url : String) : String
  UrlNormalizer.normalize(url)
end

def get_db_size(db_path : String) : Int64
  if File.exists?(db_path)
    File.size(db_path)
  else
    0_i64
  end
end

def format_bytes(bytes : Int64) : String
  units = ["B", "KB", "MB", "GB"]
  size = bytes.to_f
  unit_index = 0

  while size >= 1024 && unit_index < units.size - 1
    size /= 1024
    unit_index += 1
  end

  rounded = size.round(2)
  if rounded == rounded.to_i
    "#{rounded.to_i} #{units[unit_index]}"
  else
    "#{rounded} #{units[unit_index]}"
  end
end

def log_db_size(db_path : String, context : String = "")
  size = get_db_size(db_path)
  size_str = format_bytes(size)
  context_msg = context.empty? ? "" : " (#{context})"

  Log.for("quickheadlines.storage").info { "Database size: #{size_str}#{context_msg}" }

  if size > QuickHeadlines::Constants::DB_SIZE_HARD_LIMIT
    Log.for("quickheadlines.storage").warn { "Database exceeds hard limit (#{format_bytes(QuickHeadlines::Constants::DB_SIZE_HARD_LIMIT)})" }
  elsif size > QuickHeadlines::Constants::DB_SIZE_WARNING_THRESHOLD
    Log.for("quickheadlines.storage").warn { "Database exceeds warning threshold (#{format_bytes(QuickHeadlines::Constants::DB_SIZE_WARNING_THRESHOLD)})" }
  end
end

def ensure_cache_dir(cache_dir : String)
  unless Dir.exists?(cache_dir)
    begin
      Dir.mkdir_p(cache_dir)
      Log.for("quickheadlines.storage").info { "Created cache directory: #{cache_dir}" }
    rescue ex : File::Error
      Log.for("quickheadlines.storage").fatal(exception: ex) { "Cannot create cache directory '#{cache_dir}': #{ex.message}" }
      Log.for("quickheadlines.storage").fatal { "" }
      Log.for("quickheadlines.storage").fatal { "Solutions:" }
      Log.for("quickheadlines.storage").fatal { "  1. Set QUICKHEADLINES_CACHE_DIR to a writable location" }
      Log.for("quickheadlines.storage").fatal { "  2. Add 'cache_dir: /path/to/cache' to your feeds.yml" }
      Log.for("quickheadlines.storage").fatal { "  3. Run in a directory where you have write permissions" }
      exit 1
    end
  end
end
