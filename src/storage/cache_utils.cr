require "db"
require "sqlite3"
require "file_utils"
require "time"
require "../config"

CACHE_RETENTION_HOURS = 168

CACHE_RETENTION_DAYS = 7

DB_SIZE_WARNING_THRESHOLD = 50 * 1024 * 1024
DB_SIZE_HARD_LIMIT        = 100 * 1024 * 1024

def get_cache_dir(config : Config?) : String
  if env = ENV["QUICKHEADLINES_CACHE_DIR"]?
    return env
  end

  if config && (cache = config.cache_dir)
    return cache
  end

  if xdg = ENV["XDG_CACHE_HOME"]?
    return File.join(xdg, "quickheadlines")
  end

  if home = ENV["HOME"]?
    return File.join(home, ".cache", "quickheadlines")
  end

  "cache"
end

def get_cache_db_path(config : Config?) : String
  File.join(get_cache_dir(config), "feed_cache.db")
end

def normalize_feed_url(url : String) : String
  normalized = url.rchop('/')
  normalized = normalized.rchop("/feed")
  normalized = normalized.rchop("/rss")
  normalized = normalized.rchop("/atom")
  normalized = normalized.ends_with?('/') ? normalized : "#{normalized}/"
  normalized
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

  STDERR.puts "[#{Time.local}] Database size: #{size_str}#{context_msg}"

  if size > DB_SIZE_HARD_LIMIT
    STDERR.puts "[Cache WARNING] Database exceeds hard limit (#{format_bytes(DB_SIZE_HARD_LIMIT)})"
  elsif size > DB_SIZE_WARNING_THRESHOLD
    STDERR.puts "[Cache WARNING] Database exceeds warning threshold (#{format_bytes(DB_SIZE_WARNING_THRESHOLD)})"
  end
end

def ensure_cache_dir(cache_dir : String)
  unless Dir.exists?(cache_dir)
    begin
      Dir.mkdir_p(cache_dir)
      STDERR.puts "[#{Time.local}] Created cache directory: #{cache_dir}"
    rescue ex : File::AccessDeniedError
      STDERR.puts "Error: Cannot create cache directory '#{cache_dir}': Permission denied"
      STDERR.puts ""
      STDERR.puts "Solutions:"
      STDERR.puts "  1. Set QUICKHEADLINES_CACHE_DIR to a writable location"
      STDERR.puts "  2. Add 'cache_dir: /path/to/cache' to your feeds.yml"
      STDERR.puts "  3. Run in a directory where you have write permissions"
      exit 1
    rescue ex : Exception
      STDERR.puts "Error: Cannot create cache directory '#{cache_dir}': #{ex.message}"
      exit 1
    end
  end
end

def get_db(config : Config?, &)
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path = get_cache_db_path(config).as(String)

  DB.open("sqlite3", db_path) do |db|
    yield db
  end
end
