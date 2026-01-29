require "db"
require "sqlite3"
require "file_utils"
require "time"
require "mutex"
require "openssl"
require "./config"
require "./models"
require "lexis-minhash"
require "./favicon_storage"
require "./health_monitor"

CACHE_RETENTION_HOURS = 168

# Cache retention period in days (for cleanup)
CACHE_RETENTION_DAYS = 7

# Database size limits (in bytes)
DB_SIZE_WARNING_THRESHOLD = 50 * 1024 * 1024  # 50MB
DB_SIZE_HARD_LIMIT        = 100 * 1024 * 1024 # 100MB

# Get cache directory from various sources with fallbacks
def get_cache_dir(config : Config?) : String
  # 1. Check environment variable
  if env = ENV["QUICKHEADLINES_CACHE_DIR"]?
    return env
  end

  # 2. Check config file setting
  if config && (cache = config.cache_dir)
    return cache
  end

  # 3. Use XDG cache directory
  if xdg = ENV["XDG_CACHE_HOME"]?
    return File.join(xdg, "quickheadlines")
  end

  # 4. Fallback to platform-specific home cache
  if home = ENV["HOME"]?
    return File.join(home, ".cache", "quickheadlines")
  end

  # 5. Last resort: current directory
  "cache"
end

# Get database file path
def get_cache_db_path(config : Config?) : String
  File.join(get_cache_dir(config), "feed_cache.db")
end

# Get database file size in bytes
def get_db_size(db_path : String) : Int64
  if File.exists?(db_path)
    File.size(db_path)
  else
    0_i64
  end
end

# Format bytes to human-readable string
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

# Log database size with warnings if needed
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
  db_path = get_cache_db_path(config).as(String)

  # Open database using DB interface
  DB.open("sqlite3", db_path) do |db|
    yield db
  end
end

# Create database schema
def create_schema(db : DB::Database, db_path : String)
  # Enable WAL mode for improved concurrent access
  # WAL (write_to_file-Ahead Logging) allows concurrent reads while writing
  db.exec("PRAGMA journal_mode = WAL")

  # Set synchronous to NORMAL for better performance without sacrificing reliability
  # FULL ensures durability but is slower; NORMAL is a good balance
  db.exec("PRAGMA synchronous = NORMAL")

  # Set cache size (negative value = KB, -64000 = 64MB)
  db.exec("PRAGMA cache_size = -64000")

  # Feeds table
  db.exec <<-SQL
    CREATE TABLE IF NOT EXISTS feeds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      site_link TEXT,
      header_color TEXT,
      header_text_color TEXT,
      etag TEXT,
      last_modified TEXT,
      favicon TEXT,
      favicon_data TEXT,
      last_fetched TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    SQL

  # Migration: Add favicon_data column if it doesn't exist (for existing databases)
  begin
    db.exec("ALTER TABLE feeds ADD COLUMN favicon_data TEXT")
    STDERR.puts "[Cache] Added favicon_data column to existing database"
  rescue ex : SQLite3::Exception
    # Column already exists, ignore error
  end

  # Migration: Add header_text_color column if it doesn't exist (for existing databases)
  begin
    db.exec("ALTER TABLE feeds ADD COLUMN header_text_color TEXT")
    STDERR.puts "[Cache] Added header_text_color column to existing database"
  rescue ex : SQLite3::Exception
    # Column already exists, ignore error
  end

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
      minhash_signature BLOB,
      cluster_id INTEGER REFERENCES items(id),
      FOREIGN KEY (feed_id) REFERENCES feeds(id) ON DELETE CASCADE,
      UNIQUE(feed_id, link)
    )
    SQL

  # Migration: Add minhash_signature column if it doesn't exist (for existing databases)
  begin
    db.exec("ALTER TABLE items ADD COLUMN minhash_signature BLOB")
    STDERR.puts "[Cache] Added minhash_signature column to existing database"
  rescue ex : SQLite3::Exception
    # Column already exists, ignore error
  end

  # Migration: Add cluster_id column if it doesn't exist (for existing databases)
  begin
    db.exec("ALTER TABLE items ADD COLUMN cluster_id INTEGER REFERENCES items(id)")
    STDERR.puts "[Cache] Added cluster_id column to existing database"
  rescue ex : SQLite3::Exception
    # Column already exists, ignore error
  end

  # LSH bands table for fast similarity lookup
  db.exec <<-SQL
    CREATE TABLE IF NOT EXISTS lsh_bands (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      band_index INTEGER NOT NULL,
      band_hash INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
      UNIQUE(item_id, band_index)
    )
    SQL

  # Indexes for performance
  db.exec("CREATE INDEX IF NOT EXISTS idx_items_feed_id ON items(feed_id)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_items_pub_date ON items(pub_date DESC)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_last_fetched ON feeds(last_fetched DESC)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_items_cluster ON items(cluster_id)")
  db.exec("CREATE INDEX IF NOT EXISTS idx_lsh_band_search ON lsh_bands(band_index, band_hash)")

  # Ensure unique constraint exists (migration logic for legacy DBs)
  # If table was created before UNIQUE constraint, constraint might be missing.
  # Creating a unique index enforces this.

  # Clean up any duplicate items before creating the unique index
  # Keep the newest entry (highest id) for each (feed_id, link) pair
  cleanup_result = db.exec(<<-SQL
    DELETE FROM items
    WHERE id NOT IN (
      SELECT MAX(id)
      FROM items
      GROUP BY feed_id, link
    )
    SQL
  )

  if cleanup_result.rows_affected > 0
    STDERR.puts "[Cache] Cleaned up #{cleanup_result.rows_affected} duplicate items from database"
  end

  # Now create the unique index
  db.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_items_unique_feed_link ON items(feed_id, link)")
end

# Check database integrity
def check_db_integrity(db_path : String) : Bool
  DB.open("sqlite3://#{db_path}") do |db|
    result = db.query_one("PRAGMA integrity_check", as: {String})
    if result == "ok"
      STDERR.puts "[#{Time.local}] Database integrity check passed"
      true
    else
      STDERR.puts "[ERROR] Database integrity check failed: #{result}"
      false
    end
  end
rescue ex : Exception
  STDERR.puts "[ERROR] Database integrity check failed: #{ex.message}"
  false
end

# Enhanced database health check with multiple validations
def check_db_health(db_path : String) : DbHealthStatus
  # Check if database file exists and has content
  unless File.exists?(db_path)
    return DbHealthStatus::NeedsRepopulation
  end

  # Check file size (empty database would be very small)
  if File.size(db_path) < 100
    STDERR.puts "[WARN] Database file is too small (#{File.size(db_path)} bytes), may be empty"
    return DbHealthStatus::NeedsRepopulation
  end

  # Run integrity check
  DB.open("sqlite3://#{db_path}") do |db|
    # Check basic integrity
    integrity_result = db.query_one("PRAGMA integrity_check", as: {String})
    if integrity_result != "ok"
      STDERR.puts "[ERROR] Database integrity check failed: #{integrity_result}"
      return DbHealthStatus::Corrupted
    end

    # Check foreign key constraints
    begin
      fk_result = db.query_one("PRAGMA foreign_key_check", as: Array(Array(Int64)))
      if fk_result && !fk_result.empty?
        STDERR.puts "[WARN] Database has #{fk_result.size} foreign key violations"
        # Foreign key violations don't necessarily mean corruption
        # but we should note them
      end
    rescue ex
      # Some SQLite versions don't support this pragma in all modes
      # Ignore if not supported
    end

    # Check if database has feeds (for repopulation detection)
    feed_count = db.query_one("SELECT COUNT(*) FROM feeds", as: {Int64})
    if feed_count == 0
      STDERR.puts "[WARN] Database has no feeds, needs repopulation"
      return DbHealthStatus::NeedsRepopulation
    end

    STDERR.puts "[#{Time.local}] Database health check passed (#{feed_count} feeds)"
    DbHealthStatus::Healthy
  end
rescue ex : Exception
  STDERR.puts "[ERROR] Database health check failed: #{ex.message}"
  DbHealthStatus::Corrupted
end

# Repair corrupted database by creating a new one
def repair_database(config : Config?, backup_path : String? = nil) : DbRepairResult
  db_path = get_cache_db_path(config)
  repair_time = Time.utc

  STDERR.puts "[#{repair_time}] Attempting to repair corrupted database..."

  # Determine backup path (use provided or generate new)
  actual_backup_path = backup_path || "#{db_path}.corrupted.#{repair_time.to_s("%Y%m%d%H%M%S")}"

  # Backup corrupted database
  unless File.exists?(actual_backup_path)
    begin
      File.rename(db_path, actual_backup_path) if File.exists?(db_path)
      STDERR.puts "[#{repair_time}] Backed up corrupted database to: #{actual_backup_path}"
    rescue ex : Exception
      STDERR.puts "[ERROR] Failed to backup corrupted database: #{ex.message}"
      return DbRepairResult.new(
        status: DbHealthStatus::Corrupted,
        backup_path: nil,
        repair_time: repair_time,
        feeds_to_restore: 0,
        items_to_restore: 0
      )
    end
  end

  # Create new database
  begin
    init_db(config)
    STDERR.puts "[#{repair_time}] Successfully repaired database (created new one)"
    DbRepairResult.new(
      status: DbHealthStatus::Repaired,
      backup_path: actual_backup_path,
      repair_time: repair_time,
      feeds_to_restore: 0,
      items_to_restore: 0
    )
  rescue ex : Exception
    STDERR.puts "[ERROR] Failed to create new database: #{ex.message}"
    # Try to restore backup
    begin
      File.rename(actual_backup_path, db_path) if File.exists?(actual_backup_path)
      STDERR.puts "[#{repair_time}] Restored backup database"
    rescue
      STDERR.puts "[ERROR] Failed to restore backup database"
    end
    DbRepairResult.new(
      status: DbHealthStatus::Corrupted,
      backup_path: actual_backup_path,
      repair_time: repair_time,
      feeds_to_restore: 0,
      items_to_restore: 0
    )
  end
end

# Automatic repopulation after repair
def repopulate_database(config : Config?, cache : FeedCache?, restore_config : FeedRestoreConfig = FeedRestoreConfig.new) : Bool
  return false unless config

  STDERR.puts "[#{Time.local}] Repopulating database..."

  # Determine how many hours of feeds to fetch
  timeframe_hours = restore_config.timeframe_hours

  # Get all feeds from config
  all_feeds = [] of Feed
  all_feeds.concat(config.feeds)
  config.tabs.each do |tab|
    all_feeds.concat(tab.feeds)
  end

  feeds_to_restore = all_feeds.size
  # ameba:disable Lint/UselessAssign
  items_to_restore = 0

  # Check if we have a fetcher available (this would be called from quickheadlines.cr)
  # For now, just log what we would do
  STDERR.puts "[#{Time.local}] Would restore #{feeds_to_restore} feeds from past #{timeframe_hours} hours"

  # Return true if we have feeds to restore (actual fetching happens in the calling code)
  feeds_to_restore > 0
end

# Initialize database on first run
def init_db(config : Config?)
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path = get_cache_db_path(config)

  DB.open("sqlite3://#{db_path}") do |db|
    create_schema(db, db_path)
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

    # Compute path locally to ensure type inference is strict
    db_path = get_cache_db_path(config).as(String)
    @db_path = db_path

    # Open a single long-lived connection
    @db = DB.open("sqlite3://#{@db_path}")
    create_schema(@db, @db_path)
    STDERR.puts "[#{Time.local}] Database initialized: #{@db_path}"

    # Log database size on startup
    log_db_size(@db_path, "on startup")
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

          # Preserve existing header_color unless explicitly set in feed_data
          existing_color = @db.query_one?("SELECT header_color FROM feeds WHERE id = ?", feed_id, as: {String?})
          existing_text_color = @db.query_one?("SELECT header_text_color FROM feeds WHERE id = ?", feed_id, as: {String?})

          # Use new color if provided, otherwise keep existing
          header_color_to_save = (feed_data.header_color.nil? || feed_data.header_color.try(&.empty?) == true) ? existing_color : feed_data.header_color
          header_text_color_to_save = (feed_data.header_text_color.nil? || feed_data.header_text_color.try(&.empty?) == true) ? existing_text_color : feed_data.header_text_color

          @db.exec(
            "UPDATE feeds SET title = ?, site_link = ?, header_color = ?, header_text_color = ?, etag = ?, last_modified = ?, favicon = ?, favicon_data = ?, last_fetched = ? WHERE id = ?",
            feed_data.title,
            feed_data.site_link,
            header_color_to_save,
            header_text_color_to_save,
            feed_data.etag,
            feed_data.last_modified,
            feed_data.favicon,
            feed_data.favicon_data,
            Time.utc.to_s("%Y-%m-%d %H:%M:%S"),
            feed_id
          )

          # Delete old items that are no longer in the feed to prevent duplicates
          # Get current item links from the feed
          current_links = feed_data.items.map(&.link)
          if current_links.empty?
            # If the feed has no items, delete all items for this feed
            @db.exec("DELETE FROM items WHERE feed_id = ?", feed_id)
          else
            # Delete items that are not in the current feed
            # We need to delete items that aren't in our current_links list
            # Since we can't easily mix types in parameter binding, we'll delete in batches
            # First, get all existing links for this feed
            existing_links = [] of String
            @db.query("SELECT link FROM items WHERE feed_id = ?", feed_id) do |rows|
              rows.each do
                existing_links << rows.read(String)
              end
            end

            # Find links to delete (exist in DB but not in current feed)
            links_to_delete = existing_links - current_links
            unless links_to_delete.empty?
              # Delete items one at a time to avoid type mixing issues
              links_to_delete.each do |link|
                @db.exec("DELETE FROM items WHERE feed_id = ? AND link = ?", feed_id, link)
              end
            end
          end
        else
          # Insert new feed
          @db.exec(
            "INSERT INTO feeds (url, title, site_link, header_color, header_text_color, etag, last_modified, favicon, favicon_data, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            feed_data.url,
            feed_data.title,
            feed_data.site_link,
            feed_data.header_color,
            feed_data.header_text_color,
            feed_data.etag,
            feed_data.last_modified,
            feed_data.favicon,
            feed_data.favicon_data,
            Time.utc.to_s("%Y-%m-%d %H:%M:%S")
          )

          feed_id = @db.scalar("SELECT last_insert_rowid()").as(Int64)
        end

        # Insert items with proper upsert logic
        # First insert new items, then update pub_date for existing items if changed
        feed_data.items.each_with_index do |item, index|
          pub_date_str = item.pub_date.try(&.to_s("%Y-%m-%d %H:%M:%S"))

          # Try to insert, ignore if already exists
          @db.exec(
            "INSERT OR IGNORE INTO items (feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?)",
            feed_id,
            item.title,
            item.link,
            pub_date_str,
            item.version,
            index
          )

          # Update pub_date and position for existing items
          # This handles the case when a feed comes back online with updated timestamps
          @db.exec(
            "UPDATE items SET pub_date = ?, position = ? WHERE feed_id = ? AND link = ?",
            pub_date_str,
            index,
            feed_id,
            item.link
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
    start_time = Time.instant
    feed_data = @mutex.synchronize do
      result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
        {
          title:            row.read(String),
          url:              row.read(String),
          site_link:        row.read(String),
          header_color:     row.read(String?),
          header_text_color: row.read(String?),
          etag:             row.read(String?),
          last_modified:     row.read(String?),
          favicon:          row.read(String?),
          favicon_data:     row.read(String?),
        }
      end

      unless result
        HealthMonitor.record_cache_miss
        return
      end
      HealthMonitor.record_cache_hit

      # If favicon_data is nil but favicon is a local path, copy it
      if result[:favicon_data].nil?
        if favicon = result[:favicon]
          if favicon.starts_with?("/favicons/")
            result = {
              title:            result[:title],
              url:              result[:url],
              site_link:        result[:site_link],
              header_color:     result[:header_color],
              header_text_color: result[:header_text_color],
              etag:             result[:etag],
              last_modified:     result[:last_modified],
              favicon:          result[:favicon],
              favicon_data:     favicon,
            }
          end
        end
      end

      # Get feed_id
      feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: {Int64})
      return unless feed_id_result
      feed_id = feed_id_result

      # Get items
      items = [] of Item
      @db.query("SELECT title, link, pub_date, version FROM items WHERE feed_id = ? ORDER BY pub_date DESC", feed_id) do |rows|
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
        result[:header_text_color],
        items,
        result[:etag],
        result[:last_modified],
        result[:favicon],
        result[:favicon_data]
      )
    end
    query_time = (Time.instant - start_time).total_milliseconds
    HealthMonitor.record_db_query(query_time)
    feed_data
  end

  # Get last fetched time for a URL
  def get_fetched_time(url : String) : Time?
    @mutex.synchronize do
      result = @db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: {String})
      return unless result

      Time.parse(result, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
    end
  end

  # Get a specific slice of items for pagination
  def get_slice(url : String, limit : Int32, offset : Int32) : FeedData?
    @mutex.synchronize do
      # Get feed metadata
      result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
        {
          title:            row.read(String),
          url:              row.read(String),
          site_link:        row.read(String),
          header_color:     row.read(String?),
          header_text_color: row.read(String?),
          etag:             row.read(String?),
          last_modified:     row.read(String?),
          favicon:          row.read(String?),
          favicon_data:     row.read(String?),
        }
      end

      return unless result

      # If favicon_data is nil but favicon is a local path, copy it
      if result[:favicon_data].nil?
        if favicon = result[:favicon]
          if favicon.starts_with?("/favicons/")
            result = {
              title:            result[:title],
              url:              result[:url],
              site_link:        result[:site_link],
              header_color:     result[:header_color],
              header_text_color: result[:header_text_color],
              etag:             result[:etag],
              last_modified:     result[:last_modified],
              favicon:          result[:favicon],
              favicon_data:     favicon,
            }
          end
        end
      end

      # Get feed_id
      feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: {Int64})
      return unless feed_id_result
      feed_id = feed_id_result

      # Get items slice ordered by pub_date descending
      items = [] of Item
      query = "SELECT title, link, pub_date, version FROM items WHERE feed_id = ? ORDER BY pub_date DESC LIMIT ? OFFSET ?"

      @db.query(query, feed_id, limit, offset) do |rows|
        rows.each do
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          version = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }
          items << Item.new(title, link, pub_date, version)
        end
      end
    end

    FeedData.new(
      result[:title],
      result[:url],
      result[:site_link],
      result[:header_color],
      result[:header_text_color],
      items,
      result[:etag],
      result[:last_modified],
      result[:favicon],
      result[:favicon_data]
    )
  end

  # Update header_color for a feed (extracted from favicon via color-thief)
  # Update header_color and header_text_color for a feed (extracted from favicon via color-thief)
  # Only updates if not already set manually
  def update_header_colors(feed_url : String, bg_color : String, text_color : String)
    @mutex.synchronize do
      # First check if header_color is already set
      existing = @db.query_one?("SELECT header_color, header_text_color FROM feeds WHERE url = ?", feed_url) do |row|
        { header_color: row.read(String?), header_text_color: row.read(String?) }
      end

      # If no existing row, insert new colors
      if existing.nil?
        @db.exec("UPDATE feeds SET header_color = ?, header_text_color = ? WHERE url = ?", bg_color, text_color, feed_url)
        STDERR.puts "[#{Time.local}] Saved extracted header colors for #{feed_url}: bg=#{bg_color}, text=#{text_color}"
      else
        should_update_bg = existing[:header_color].nil? || existing[:header_color] == ""
        should_update_text = existing[:header_text_color].nil? || existing[:header_text_color] == ""

        if should_update_bg || should_update_text
          updates = [] of String
          values = [] of String

          if should_update_bg
            updates << "header_color = ?"
            values << bg_color
          end

          if should_update_text
            updates << "header_text_color = ?"
            values << text_color
          end

        unless updates.empty?
          query = "UPDATE feeds SET " + updates.join(", ") + " WHERE url = ?"
          values << feed_url
          @db.exec(query, args: values)
          STDERR.puts "[#{Time.local}] Saved extracted header colors for #{feed_url}: bg=#{bg_color}, text=#{text_color}"
        end
        else
          STDERR.puts "[#{Time.local}] Skipped header colors for #{feed_url}: already set"
        end
      end
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
      # Log size before cleanup
      log_db_size(@db_path, "before cleanup")

      cutoff = (Time.utc - retention_hours.hours).to_s("%Y-%m-%d %H:%M:%S")

      # Delete feeds (cascade deletes items)
      result = @db.exec("DELETE FROM feeds WHERE last_fetched < ?", cutoff)
      deleted_count = result.rows_affected
      STDERR.puts "[#{Time.local}] Cleaned up #{deleted_count} old feeds (older than #{retention_hours}h)" if deleted_count > 0

      # Log size after cleanup
      log_db_size(@db_path, "after cleanup")
    end
  end

  # Clean up old cached articles based on pub_date (for timeline)
  # This removes articles older than CACHE_RETENTION_DAYS to keep timeline fresh
  def cleanup_old_articles(retention_days : Int32 = CACHE_RETENTION_DAYS)
    @mutex.synchronize do
      cutoff = (Time.utc - retention_days.days).to_s("%Y-%m-%d %H:%M:%S")

      # Delete items with pub_date older than cutoff
      result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
      deleted_count = result.rows_affected

      if deleted_count > 0
        STDERR.puts "[#{Time.local}] Cleaned up #{deleted_count} old articles (older than #{retention_days} days)"
      end

      # Clean up orphaned items (items whose feeds no longer exist)
      result = @db.exec("DELETE FROM items WHERE feed_id NOT IN (SELECT id FROM feeds)")
      orphaned_count = result.rows_affected

      if orphaned_count > 0
        STDERR.puts "[#{Time.local}] Cleaned up #{orphaned_count} orphaned items"
      end

      # Clean up feeds with no items
      result = @db.exec("DELETE FROM feeds WHERE id NOT IN (SELECT DISTINCT feed_id FROM items)")
      empty_feeds = result.rows_affected

      if empty_feeds > 0
        STDERR.puts "[#{Time.local}] Cleaned up #{empty_feeds} empty feeds"
      end
    end
  end

  # Full cleanup: removes old articles and optimizes database
  def full_cleanup(retention_days : Int32 = CACHE_RETENTION_DAYS)
    cleanup_old_articles(retention_days)

    # Vacuum to reclaim space after cleanup
    @db.exec("VACUUM")
    STDERR.puts "[#{Time.local}] Database vacuumed after cleanup"
  end

  # Clean up oldest entries until database is under size limit
  def cleanup_by_size(max_size : Int64)
    @mutex.synchronize do
      current_size = get_db_size(@db_path)

      return if current_size <= max_size

      STDERR.puts "[#{Time.local}] Database size (#{format_bytes(current_size)}) exceeds limit (#{format_bytes(max_size)}), cleaning up oldest entries..."

      # Delete oldest items first, regardless of age
      # We delete items in batches to avoid long-running transactions
      total_deleted = 0

      while current_size > max_size
        # Delete oldest 1000 items
        result = @db.exec(<<-SQL
          DELETE FROM items
          WHERE id IN (
            SELECT id FROM items
            ORDER BY pub_date ASC
            LIMIT 1000
          )
          SQL
        )
        deleted = result.rows_affected
        total_deleted += deleted

        # Break if no more items to delete
        break if deleted == 0

        # Check size again
        current_size = get_db_size(@db_path)

        # Also clean up feeds with no items
        @db.exec(<<-SQL
          DELETE FROM feeds
          WHERE id NOT IN (SELECT DISTINCT feed_id FROM items)
          SQL
        )
      end

      STDERR.puts "[#{Time.local}] Cleaned up #{total_deleted} items to reduce database size to #{format_bytes(current_size)}"
      log_db_size(@db_path, "after size cleanup")
    end
  end

  # Vacuum database to reclaim space
  def vacuum
    @mutex.synchronize do
      @db.exec("VACUUM")
    end
  end

  # Sync favicon paths to ensure database points to local files
  # This is an aggressive cleanup that:
  # 1. Clears favicon_data if it contains external URLs
  # 2. Copies local paths from favicon to favicon_data where missing
  # 3. Ensures both columns point to local paths when possible
  def sync_favicon_paths
    @mutex.synchronize do
      # Collect all feed data first to avoid modifying DB while iterating
      feeds_data = [] of {Int64, String, String, String?}

      @db.query("SELECT id, url, favicon, favicon_data FROM feeds WHERE favicon IS NOT NULL") do |rows|
        rows.each do
          feed_id = rows.read(Int64)
          url = rows.read(String)
          favicon = rows.read(String)
          favicon_data = rows.read(String?)
          feeds_data << {feed_id, url, favicon, favicon_data}
        end
      end

      # Now process updates in a separate pass
      feeds_data.each do |feed_id, url, favicon, favicon_data|
        # Case 1: favicon_data contains an external URL - clear it
        if favicon_data && favicon_data.starts_with?("http")
          @db.exec("UPDATE feeds SET favicon_data = NULL WHERE id = ?", feed_id)
          STDERR.puts "[Cache] Cleared external URL from favicon_data for #{url}: #{favicon_data}"
          favicon_data = nil
        end

        # Case 2: favicon_data is nil but favicon is a local path - copy it
        if favicon_data.nil? && favicon.starts_with?("/favicons/")
          @db.exec("UPDATE feeds SET favicon_data = ? WHERE id = ?", favicon, feed_id)
          STDERR.puts "[Cache] Synced favicon_data for #{url}: #{favicon}"
        end

        # Case 3: favicon is an external URL, check if we have a local file
        if favicon.starts_with?("http")
          # Generate hash-based filename from the URL
          hash = OpenSSL::Digest.new("SHA256").update(favicon).final.hexstring
          possible_extensions = ["png", "jpg", "jpeg", "ico", "svg", "webp"]

          found_local = false
          possible_extensions.each do |ext|
            filename = "#{hash[0...16]}.#{ext}"
            filepath = File.join(FaviconStorage::FAVICON_DIR, filename)
            if File.exists?(filepath)
              local_path = "/favicons/#{filename}"
              # Update database to point to local file in both columns
              @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", local_path, local_path, feed_id)
              STDERR.puts "[Cache] Synced favicon for #{url}: #{favicon} -> #{local_path}"
              found_local = true
              break
            end
          end

          # If no local file found, clear both columns to force refetch
          unless found_local
            @db.exec("UPDATE feeds SET favicon = NULL, favicon_data = NULL WHERE id = ?", feed_id)
            STDERR.puts "[Cache] Cleared missing favicon for #{url}: #{favicon}"
          end
        end
      end
    end
  end

  # ============================================
  # Story Grouping / Clustering Methods
  # ============================================

  # Store MinHash signature for an item
  def store_item_signature(item_id : Int64, signature : Array(UInt32))
    @mutex.synchronize do
      bytes = LexisMinhash::Engine.signature_to_bytes(signature)
      @db.exec("UPDATE items SET minhash_signature = ? WHERE id = ?", bytes, item_id)
    end
  end

  # Get MinHash signature for an item
  def get_item_signature(item_id : Int64) : Array(UInt32)?
    @mutex.synchronize do
      result = @db.query_one?("SELECT minhash_signature FROM items WHERE id = ?", item_id, as: {Bytes?})
      return unless result
      LexisMinhash::Engine.bytes_to_signature(result)
    end
  end

  # Store LSH bands for an item
  def store_lsh_bands(item_id : Int64, bands : Array({Int32, UInt64}))
    @mutex.synchronize do
      @db.exec("BEGIN TRANSACTION")
      begin
        # Delete existing bands for this item
        @db.exec("DELETE FROM lsh_bands WHERE item_id = ?", item_id)

        # Insert new bands (convert UInt64 to Int64 for SQLite)
        bands.each do |band_index, band_hash|
          @db.exec(
            "INSERT INTO lsh_bands (item_id, band_index, band_hash, created_at) VALUES (?, ?, ?, ?)",
            item_id,
            band_index,
            band_hash.to_i64,
            Time.utc.to_s("%Y-%m-%d %H:%M:%S")
          )
        end
        @db.exec("COMMIT")
      rescue ex
        @db.exec("ROLLBACK")
        STDERR.puts "[Cache ERROR] Failed to store LSH bands for item #{item_id}: #{ex.message}"
      end
    end
  end

  # Find candidate similar items using LSH
  # Returns item IDs that share at least one LSH band
  def find_lsh_candidates(signature : Array(UInt32)) : Array(Int64)
    bands = LexisMinhash::Engine.generate_bands(signature)
    candidates = Set(Int64).new

    @mutex.synchronize do
      bands.each do |band_index, band_hash|
        # Convert UInt64 to Int64 for SQLite compatibility
        band_hash_int = band_hash.to_i64
        @db.query("SELECT DISTINCT item_id FROM lsh_bands WHERE band_index = ? AND band_hash = ?", band_index, band_hash_int) do |rows|
          rows.each do
            item_id = rows.read(Int64)
            candidates << item_id
          end
        end
      end
    end

    candidates.to_a
  end

  # Assign an item to a cluster
  def assign_cluster(item_id : Int64, cluster_id : Int64?)
    @mutex.synchronize do
      @db.exec("UPDATE items SET cluster_id = ? WHERE id = ?", cluster_id, item_id)
    end
  end

  # Get all item IDs in a cluster
  def get_cluster_items(cluster_id : Int64) : Array(Int64)
    items = [] of Int64
    @mutex.synchronize do
      @db.query("SELECT id FROM items WHERE cluster_id = ? ORDER BY id ASC", cluster_id) do |rows|
        rows.each do
          items << rows.read(Int64)
        end
      end
    end
    items
  end

  # Get the cluster size for an item
  def get_cluster_size(item_id : Int64) : Int32
    @mutex.synchronize do
      result = @db.query_one?(
        "SELECT COUNT(*) FROM items WHERE cluster_id = (SELECT cluster_id FROM items WHERE id = ?)",
        item_id,
        as: {Int64}
      )
      result ? result.to_i : 1
    end
  end

  # Check if an item is the representative (first in cluster)
  def cluster_representative?(item_id : Int64) : Bool
    @mutex.synchronize do
      cluster_id = @db.query_one?("SELECT cluster_id FROM items WHERE id = ?", item_id, as: {Int64?})
      return true unless cluster_id

      # Get the minimum item_id in the cluster (that's the representative)
      min_id = @db.query_one?(
        "SELECT MIN(id) FROM items WHERE cluster_id = ?",
        cluster_id,
        as: {Int64}
      )
      min_id == item_id
    end
  end

  # Get item ID by feed URL and link
  def get_item_id(feed_url : String, item_link : String) : Int64?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT items.id FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ? AND items.link = ?",
        feed_url,
        item_link,
        as: {Int64}
      )
    end
  end

  # Public getter for database (for cluster queries)
  def db : DB::Database
    @db
  end

  # Get recent items for clustering (last N hours, limit max items)
  def get_recent_items_for_clustering(hours_back : Int32 = 24, max_items : Int32 = 1000) : Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})
    @mutex.synchronize do
      cutoff = (Time.utc - hours_back.hours).to_s("%Y-%m-%d %H:%M:%S")

      items = [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?}

      query = <<-SQL
        SELECT i.id, i.title, i.link, i.pub_date, f.url as feed_url, f.title as feed_title, f.favicon, f.header_color
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        WHERE i.pub_date >= ?
        ORDER BY i.pub_date DESC
        LIMIT ?
      SQL

      @db.query(query, cutoff, max_items) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          feed_url = rows.read(String)
          feed_title = rows.read(String)
          favicon = rows.read(String?)
          header_color = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          items << {
            id: id,
            title: title,
            link: link,
            pub_date: pub_date,
            feed_url: feed_url,
            feed_title: feed_title,
            favicon: favicon,
            header_color: header_color
          }
        end
      end

      items
    end
  end

  # Get all clusters with their items
  def get_all_clusters : Array({id: Int64, representative_id: Int64, item_count: Int32})
    @mutex.synchronize do
      clusters = [] of {id: Int64, representative_id: Int64, item_count: Int32}

      # Get all clusters (items that have a cluster_id)
      query = <<-SQL
        SELECT c.id, MIN(c.representative_id) as representative_id, COUNT(*) as item_count
        FROM (
          SELECT cluster_id as id, MIN(id) as representative_id
          FROM items
          WHERE cluster_id IS NOT NULL
          GROUP BY cluster_id
        ) c
        JOIN items i ON i.cluster_id = c.id
        GROUP BY c.id
        ORDER BY MIN(i.pub_date) DESC
      SQL

      @db.query(query) do |rows|
        rows.each do
          cluster_id = rows.read(Int64)
          representative_id = rows.read(Int64)
          item_count = rows.read(Int64).to_i32
          clusters << {id: cluster_id, representative_id: representative_id, item_count: item_count}
        end
      end

      clusters
    end
  end

  # Get items in a cluster
  def get_cluster_items_full(cluster_id : Int64) : Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})
    @mutex.synchronize do
      items = [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?}

      query = <<-SQL
        SELECT i.id, i.title, i.link, i.pub_date, f.url as feed_url, f.title as feed_title, f.favicon, f.header_color
        FROM items i
        JOIN feeds f ON i.feed_id = f.id
        WHERE i.cluster_id = ?
        ORDER BY i.id ASC
      SQL

      @db.query(query, cluster_id) do |rows|
        rows.each do
          id = rows.read(Int64)
          title = rows.read(String)
          link = rows.read(String)
          pub_date_str = rows.read(String?)
          feed_url = rows.read(String)
          feed_title = rows.read(String)
          favicon = rows.read(String?)
          header_color = rows.read(String?)

          pub_date = pub_date_str.try { |date_str| Time.parse(date_str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

          items << {
            id: id,
            title: title,
            link: link,
            pub_date: pub_date,
            feed_url: feed_url,
            feed_title: feed_title,
            favicon: favicon,
            header_color: header_color
          }
        end
      end

      items
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
    result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
      {
        title:            row.read(String),
        url:              row.read(String),
        site_link:        row.read(String),
        header_color:     row.read(String?),
        header_text_color: row.read(String?),
        etag:             row.read(String?),
        last_modified:     row.read(String?),
        favicon:          row.read(String?),
        favicon_data:     row.read(String?),
      }
    end

    return unless result

    # If favicon_data is nil but favicon is a local path, copy it
    if result[:favicon_data].nil?
      if favicon = result[:favicon]
        if favicon.starts_with?("/favicons/")
          result = {
            title:            result[:title],
            url:              result[:url],
            site_link:        result[:site_link],
            header_color:     result[:header_color],
            header_text_color: result[:header_text_color],
            etag:             result[:etag],
            last_modified:     result[:last_modified],
            favicon:          result[:favicon],
            favicon_data:     favicon,
          }
        end
      end
    end

    # Get feed_id
    feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: {Int64})
    return unless feed_id_result
    feed_id = feed_id_result

    # Get items
    items = [] of Item
    @db.query("SELECT title, link, pub_date, version FROM items WHERE feed_id = ? ORDER BY pub_date DESC", feed_id) do |rows|
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
      result[:header_text_color],
      items,
      result[:etag],
      result[:last_modified],
      result[:favicon],
      result[:favicon_data]
    )
  end
end

# Load cache from disk with enhanced recovery (returns FeedCache instance)
def load_feed_cache(config : Config?) : FeedCache
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path : String = get_cache_db_path(config)

  # Initialize DB if first run
  init_db(config) unless File.exists?(db_path)

  # Enhanced health check on startup
  if File.exists?(db_path)
    health_status = check_db_health(db_path)

    case health_status
    when DbHealthStatus::Healthy
      STDERR.puts "[#{Time.local}] Database is healthy"
    when DbHealthStatus::Corrupted
      STDERR.puts "[ERROR] Database corruption detected, attempting repair..."
      repair_result = repair_database(config)

      if repair_result.status == DbHealthStatus::Repaired
        STDERR.puts "[#{Time.local}] Database was previously repaired"
      end
    end
  end

  cache = FeedCache.new(config)

  # Sync favicon paths to ensure database points to local files
  cache.sync_favicon_paths

  # Clean up old articles to keep timeline fresh (only if DB is healthy)
  if health_status == DbHealthStatus::Healthy
    cache.cleanup_old_articles(CACHE_RETENTION_DAYS)
  end

  # Get retention hours from config or use default
  retention_hours = config.try(&.cache_retention_hours) || CACHE_RETENTION_HOURS

  # Clean up old entries on load
  cache.cleanup_old_entries(retention_hours)

  # Check if database exceeds hard limit and clean up by size if needed
  db_size = get_db_size(db_path)
  if db_size > DB_SIZE_HARD_LIMIT
    cache.cleanup_by_size(DB_SIZE_HARD_LIMIT)
  end

  # Vacuum if database is getting large (over 10MB)
  if db_size > 10 * 1024 * 1024
    cache.vacuum
  end

  cache
end

# Save cache (SQLite auto-commits, but we vacuum occasionally)
def save_feed_cache(cache : FeedCache, retention_hours : Int32 = CACHE_RETENTION_HOURS)
  # SQLite saves immediately, but we can vacuum occasionally to optimize
  # This is called after each refresh to periodically optimize
  if rand(100) < 5 # 5% chance to vacuum
    begin
      cache.vacuum
    rescue ex
      # Vacuum can fail if database is locked, ignore
    end
  end

  # Periodically clean up old entries based on retention
  if rand(100) < 10 # 10% chance to run cleanup
    cache.cleanup_old_entries(retention_hours)
  end

  # Sync favicon paths to ensure database points to local files
  cache.sync_favicon_paths
end

# Check if cache is fresh (within X minutes)
def cache_fresh?(last_fetched : Time, max_age_minutes : Int32 = 10) : Bool
  (Time.utc - last_fetched).total_minutes < max_age_minutes
end
