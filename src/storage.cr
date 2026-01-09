require "db"
require "sqlite3"
require "file_utils"
require "time"
require "mutex"
require "./models"

CACHE_RETENTION_HOURS = 24

# Get cache directory from various sources with fallbacks
def get_cache_dir(config : Config?) : String
  # 1. Check environment variable
  if env_dir = ENV.fetch("QUICKHEADLINES_CACHE_DIR", nil)
    return env_dir
  end

  # 2. Check config file setting
  if config_dir = config.try(&.cache_dir)
    return config_dir
  end

  # 3. Use XDG cache directory
  if xdg_cache = ENV.fetch("XDG_CACHE_HOME", nil)
    return File.join(xdg_cache, "quickheadlines")
  end

  # 4. Fallback to platform-specific home cache
  home = ENV.fetch("HOME", nil)
  if home
    return File.join(home, ".cache", "quickheadlines")
  end

  # 5. Last resort: current directory
  "cache"
end

# Get database file path
def get_cache_db_path(config : Config?) : String
  cache_dir = get_cache_dir(config)
  File.join(cache_dir, "feed_cache.db")
end

# Ensure cache directory exists with proper error handling
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

# Get or create database connection
def get_db(config : Config?, &)
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path = get_cache_db_path(config)

  # Open database using DB interface
  DB.open("sqlite3", db_path) do |db|
    yield db
  end
end

# Create database schema
def create_schema(db : DB::Database)
  # Feeds table
  db.exec <<-SQL
    CREATE TABLE IF NOT EXISTS feeds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      site_link TEXT,
      header_color TEXT,
      etag TEXT,
      last_modified TEXT,
      favicon TEXT,
      last_fetched TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    SQL

  # Items table
  db.exec <<-SQL
    CREATE TABLE IF NOT EXISTS items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      feed_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      link TEXT NOT NULL,
      pub_date TEXT,
      version TEXT,
      position INTEGER NOT NULL,
      FOREIGN KEY (feed_id) REFERENCES feeds(id) ON DELETE CASCADE
    )
    SQL

  # Indexes for performance
  db.exec("CREATE INDEX IF NOT EXISTS idx_items_feed_id ON items(feed_id)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_items_pub_date ON items(pub_date DESC)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_last_fetched ON feeds(last_fetched DESC)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url)")
end

# Initialize database on first run
def init_db(config : Config?)
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path = get_cache_db_path(config)

  DB.open("sqlite3://#{db_path}") do |db|
    create_schema(db)
  end
end

# FeedCache class - wrapper around SQLite database
class FeedCache
  @mutex : Mutex
  @db : DB::Database
  @db_path : String

  def initialize(config : Config?)
    @mutex = Mutex.new
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)
    @db_path = get_cache_db_path(config)

    # Open a single long-lived connection
    @db = DB.open("sqlite3://#{@db_path}")
    create_schema(@db)
    STDERR.puts "[#{Time.local}] Database initialized: #{@db_path}"
  end

  # Add a feed and its items to the cache
  def add(feed_data : FeedData)
    @mutex.synchronize do
      begin
        @db.exec("BEGIN TRANSACTION")

        # Check if feed exists
        result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_data.url, as: {Int64})

        if result
          # Update existing feed
          feed_id = result

          @db.exec(
            "UPDATE feeds SET title = ?, site_link = ?, header_color = ?, etag = ?, last_modified = ?, favicon = ?, last_fetched = ? WHERE id = ?",
            feed_data.title,
            feed_data.site_link,
            feed_data.header_color,
            feed_data.etag,
            feed_data.last_modified,
            feed_data.favicon,
            Time.utc.to_s("%Y-%m-%d %H:%M:%S"),
            feed_id
          )

          # Delete old items
          @db.exec("DELETE FROM items WHERE feed_id = ?", feed_id)
        else
          # Insert new feed
          @db.exec(
            "INSERT INTO feeds (url, title, site_link, header_color, etag, last_modified, favicon, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            feed_data.url,
            feed_data.title,
            feed_data.site_link,
            feed_data.header_color,
            feed_data.etag,
            feed_data.last_modified,
            feed_data.favicon,
            Time.utc.to_s("%Y-%m-%d %H:%M:%S")
          )

          feed_id = @db.scalar("SELECT last_insert_rowid()").as(Int64)
        end

        # Insert items
        feed_data.items.each_with_index do |item, index|
          pub_date_str = item.pub_date.try(&.to_s("%Y-%m-%d %H:%M:%S"))

          @db.exec(
            "INSERT INTO items (feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?)",
            feed_id,
            item.title,
            item.link,
            pub_date_str,
            item.version,
            index
          )
        end

        @db.exec("COMMIT")
      rescue ex
        STDERR.puts "[Cache ERROR] Failed to add feed #{feed_data.title}: #{ex.message}"
        begin
          @db.exec("ROLLBACK")
        rescue
          # Ignore rollback errors
        end
        # Don't re-raise, just log the error
      end
    end
  end

  # Get a feed from cache by URL
  def get(url : String) : FeedData?
    @mutex.synchronize do
      result = @db.query_one?("SELECT title, url, site_link, header_color, etag, last_modified, favicon FROM feeds WHERE url = ?", url) do |row|
        {
          title:         row.read(String),
          url:           row.read(String),
          site_link:     row.read(String),
          header_color:  row.read(String?),
          etag:          row.read(String?),
          last_modified: row.read(String?),
          favicon:       row.read(String?),
        }
      end

      # ameba:disable Style/RedundantNilInControlExpression
      return nil unless result

      # Get feed_id
      feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: {Int64})
      # ameba:disable Style/RedundantNilInControlExpression
      return nil unless feed_id_result
      feed_id = feed_id_result

      # Get items
      items = [] of Item
      @db.query("SELECT title, link, pub_date, version FROM items WHERE feed_id = ? ORDER BY position ASC", feed_id) do |rows|
        rows.each do
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          version = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }
          items << Item.new(title, link, pub_date, version)
        end
      end

      FeedData.new(
        result[:title],
        result[:url],
        result[:site_link],
        result[:header_color],
        items,
        result[:etag],
        result[:last_modified],
        result[:favicon],
        nil # Don't cache favicon_data
      )
    end
  end

  # Get last fetched time for a URL
  def get_fetched_time(url : String) : Time?
    @mutex.synchronize do
      result = @db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: {String})
      # ameba:disable Style/RedundantNilInControlExpression
      return nil unless result

      Time.parse(result, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
    end
  end

  # Get all URLs in cache
  def entries : Hash(String, FeedData)
    @mutex.synchronize do
      urls = {} of String => FeedData

      @db.query("SELECT url FROM feeds") do |rows|
        rows.each do
          url = rows.read(String)
          if feed = get_without_lock(url)
            urls[url] = feed
          end
        end
      end

      urls
    end
  end

  # Get the number of feeds in cache
  def size : Int32
    @mutex.synchronize do
      result = @db.query_one?("SELECT COUNT(*) FROM feeds", as: {Int64})
      result ? result.to_i : 0
    end
  end

  # Clean up old entries based on retention time
  def cleanup_old_entries(retention_hours : Int32 = CACHE_RETENTION_HOURS)
    @mutex.synchronize do
      cutoff = (Time.utc - retention_hours.hours).to_s("%Y-%m-%d %H:%M:%S")

      # Delete feeds (cascade deletes items)
      result = @db.exec("DELETE FROM feeds WHERE last_fetched < ?", cutoff)
      deleted_count = result.rows_affected
      STDERR.puts "[#{Time.local}] Cleaned up #{deleted_count} old feeds (older than #{retention_hours}h)" if deleted_count > 0
    end
  end

  # Vacuum database to reclaim space
  def vacuum
    @mutex.synchronize do
      @db.exec("VACUUM")
    end
  end

  # Close database connection
  def close
    @mutex.synchronize do
      @db.close
    end
  end

  # Private helper to get feed without acquiring lock (already in mutex)
  private def get_without_lock(url : String) : FeedData?
    result = @db.query_one?("SELECT title, url, site_link, header_color, etag, last_modified, favicon FROM feeds WHERE url = ?", url) do |row|
      {
        title:         row.read(String),
        url:           row.read(String),
        site_link:     row.read(String),
        header_color:  row.read(String?),
        etag:          row.read(String?),
        last_modified: row.read(String?),
        favicon:       row.read(String?),
      }
    end

    # ameba:disable Style/RedundantNilInControlExpression
    return nil unless result

    # Get feed_id
    feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: {Int64})
    # ameba:disable Style/RedundantNilInControlExpression
    return nil unless feed_id_result
    feed_id = feed_id_result

    # Get items
    items = [] of Item
    @db.query("SELECT title, link, pub_date, version FROM items WHERE feed_id = ? ORDER BY position ASC", feed_id) do |rows|
      rows.each do
        title = rows.read(String)
        link = rows.read(String)
        pub_date_str = rows.read(String?)
        version = rows.read(String?)

        pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }
        items << Item.new(title, link, pub_date, version)
      end
    end

    FeedData.new(
      result[:title],
      result[:url],
      result[:site_link],
      result[:header_color],
      items,
      result[:etag],
      result[:last_modified],
      result[:favicon],
      nil # Don't cache favicon_data
    )
  end
end

# Load cache from disk (returns FeedCache instance)
def load_feed_cache(config : Config?) : FeedCache
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path = get_cache_db_path(config)

  # Initialize DB if first run
  init_db(config) unless File.exists?(db_path)

  cache = FeedCache.new(config)

  # Clean up old entries on load
  cache.cleanup_old_entries

  # Vacuum if database is getting large
  if File.size(db_path) > 10 * 1024 * 1024 # 10MB
    cache.vacuum
  end

  cache
end

# Save cache (SQLite auto-commits, but we vacuum occasionally)
def save_feed_cache(cache : FeedCache)
  # SQLite saves immediately, but we can vacuum occasionally to optimize
  # This is called after each refresh to periodically optimize
  if rand(100) < 5 # 5% chance to vacuum
    begin
      cache.vacuum
    rescue ex
      # Vacuum can fail if database is locked, ignore
    end
  end
end

# Check if cache is fresh (within X minutes)
def cache_fresh?(last_fetched : Time, max_age_minutes : Int32 = 10) : Bool
  (Time.utc - last_fetched).total_minutes < max_age_minutes
end
