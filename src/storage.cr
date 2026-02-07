require "db"
require "sqlite3"
require "file_utils"
require "time"
require "mutex"
require "openssl"
require "./config"
require "./models"
require "./favicon_storage"
require "./color_extractor"
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

# Normalize feed URL for consistent matching
def normalize_feed_url(url : String) : String
  # Strip trailing slash
  normalized = url.rchop('/')
  # Remove common feed path suffixes
  normalized = normalized.rchop("/feed")
  normalized = normalized.rchop("/rss")
  normalized = normalized.rchop("/atom")
  # Ensure consistent trailing slash if not present
  normalized = normalized.ends_with?('/') ? normalized : "#{normalized}/"
  normalized
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
      header_theme_colors TEXT,
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

  # Migration: Add header_theme_colors column if it doesn't exist (for existing databases)
  begin
    db.exec("ALTER TABLE feeds ADD COLUMN header_theme_colors TEXT")
    STDERR.puts "[Cache] Added header_theme_colors column to existing database"
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
  actual_backup_path = backup_path || "#{db_path}.corrupted.#{repair_time.to_s("%Y%m%d%H%M%S") }"

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

  getter :db_path

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

          # Preserve existing header_color/text and header_theme_colors unless explicitly set in feed_data
          existing_color = @db.query_one?("SELECT header_color FROM feeds WHERE id = ?", feed_id, as: {String?})
          existing_text_color = @db.query_one?("SELECT header_text_color FROM feeds WHERE id = ?", feed_id, as: {String?})
          existing_theme = @db.query_one?("SELECT header_theme_colors FROM feeds WHERE id = ?", feed_id, as: {String?})

          # Use new color if provided, otherwise keep existing
          # Only preserve existing color if feed_data.header_color is nil
          # Extracted colors should be saved; nil means extraction failed/skipped
           header_color_to_save = feed_data.header_color.nil? ? existing_color : feed_data.header_color
           header_text_color_to_save = feed_data.header_text_color.nil? ? existing_text_color : feed_data.header_text_color
           header_theme_to_save = feed_data.header_theme_colors.nil? ? existing_theme : feed_data.header_theme_colors

           # Auto-correct theme JSON before persisting. Use legacy header_color/text as fallbacks.
           begin
             corrected = ColorExtractor.auto_correct_theme_json(header_theme_to_save, header_color_to_save, header_text_color_to_save)
             header_theme_to_save = corrected if corrected
           rescue
             # On failure, keep the original payload
           end

            @db.exec(
              "UPDATE feeds SET title = ?, site_link = ?, header_color = ?, header_text_color = ?, header_theme_colors = ?, etag = ?, last_modified = ?, favicon = ?, favicon_data = ?, last_fetched = ? WHERE id = ?",
              feed_data.title,
              feed_data.site_link,
              header_color_to_save,
              header_text_color_to_save,
              header_theme_to_save,
              feed_data.etag,
              feed_data.last_modified,
              feed_data.favicon,
              feed_data.favicon_data,
              Time.utc.to_s("%Y-%m-%d %H:%M:%S"),
              feed_id
            )

          # NOTE: We do NOT delete old items here anymore.
          # The system is designed to accumulate items over time (7 days retention).
          # Old items are cleaned up by cleanup_old_articles() based on pub_date.
        else
          # Insert new feed
            # Auto-correct theme JSON for new inserts as well
            begin
              incoming_theme = feed_data.header_theme_colors
              corrected_incoming = ColorExtractor.auto_correct_theme_json(incoming_theme, feed_data.header_color, feed_data.header_text_color)
              theme_to_insert = corrected_incoming || incoming_theme
            rescue
              theme_to_insert = feed_data.header_theme_colors
            end

            @db.exec(
              "INSERT INTO feeds (url, title, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
              feed_data.url,
              feed_data.title,
              feed_data.site_link,
              feed_data.header_color,
              feed_data.header_text_color,
              theme_to_insert,
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
    start_time = Time.monotonic
    feed_data = @mutex.synchronize do
      result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
        {
          title:             row.read(String),
          url:               row.read(String),
          site_link:         row.read(String),
          header_color:      row.read(String?),
          header_text_color: row.read(String?),
          header_theme_colors: row.read(String?),
          etag:              row.read(String?),
          last_modified:     row.read(String?),
          favicon:           row.read(String?),
          favicon_data:      row.read(String?),
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
              title:                result[:title],
              url:                  result[:url],
              site_link:            result[:site_link],
              header_color:         result[:header_color],
              header_text_color:    result[:header_text_color],
              header_theme_colors:  result[:header_theme_colors],
              etag:                 result[:etag],
              last_modified:        result[:last_modified],
              favicon:              result[:favicon],
              favicon_data:         favicon,
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

      fd = FeedData.new(
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
      # Restore theme-aware JSON into the FeedData instance
      fd.header_theme_colors = result[:header_theme_colors] if result[:header_theme_colors]
      fd
    end
    query_time = (Time.monotonic - start_time).total_milliseconds
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
      feed_result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
        {
          title:             row.read(String),
          url:               row.read(String),
          site_link:         row.read(String),
          header_color:      row.read(String?),
          header_text_color: row.read(String?),
          header_theme_colors: row.read(String?),
          etag:              row.read(String?),
          last_modified:     row.read(String?),
          favicon:           row.read(String?),
          favicon_data:      row.read(String?),
        }
      end
      return unless feed_result

      # Get items slice ordered by pub_date descending
      items = [] of Item
      query = "SELECT title, link, pub_date, version FROM items WHERE feed_id = ? ORDER BY pub_date DESC LIMIT ? OFFSET ?"

      @db.query(query, url, limit, offset) do |rows|
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

    fd = FeedData.new(
      feed_result[:title],
      feed_result[:url],
      feed_result[:site_link],
      feed_result[:header_color],
      feed_result[:header_text_color],
      items,
      feed_result[:etag],
      feed_result[:last_modified],
      feed_result[:favicon],
      feed_result[:favicon_data]
    )
    fd.header_theme_colors = feed_result[:header_theme_colors] if feed_result[:header_theme_colors]
    fd
  end

  # Update header_color for a feed (extracted from favicon via color-thief)
  # Update header_color and header_text_color for a feed (extracted from favicon via color-thief)
  # Only updates if not already set manually
  def update_header_colors(feed_url : String, bg_color : String, text_color : String)
    @mutex.synchronize do
      # Normalize the URL for matching
      normalized_url = normalize_feed_url(feed_url)

      # First check if header_color is already set
      existing = @db.query_one?("SELECT header_color, header_text_color FROM feeds WHERE url = ?", normalized_url) do |row|
        {header_color: row.read(String?), header_text_color: row.read(String?)}
      end

      if existing.nil?
        # Try to find with original URL
        existing = @db.query_one?("SELECT header_color, header_text_color FROM feeds WHERE url = ?", feed_url) do |row|
          {header_color: row.read(String?), header_text_color: row.read(String?)}
        end
      end

      if existing.nil?
        # Row doesn't exist - log warning with debugging info
        all_urls = @db.query_all("SELECT url FROM feeds LIMIT 10", as: String)
        STDERR.puts "[#{Time.local}] Warning: Feed '#{feed_url}' not found in database. Sample DB URLs: #{all_urls.join(", ")}"
        return
      end

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

  # Get header colors for a specific feed URL from the database
  def get_header_colors(feed_url : String) : {bg_color: String?, text_color: String?}
    @mutex.synchronize do
      result = @db.query_one?("SELECT header_color, header_text_color FROM feeds WHERE url = ?", feed_url) do |row|
        {bg_color: row.read(String?), text_color: row.read(String?)}
      end
      result || {bg_color: nil, text_color: nil}
    end
  end

  # Persist theme-aware header colors JSON for a feed (mutex-protected)
  def update_feed_theme_colors(feed_url : String, theme_json : String)
    @mutex.synchronize do
      normalized_url = normalize_feed_url(feed_url)

      # Try to find the feed by normalized URL first
      existing = @db.query_one?("SELECT id FROM feeds WHERE url = ?", normalized_url, as: {Int64})

      if existing.nil?
        # Try with original URL
        existing = @db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_url, as: {Int64})
      end

      unless existing
        STDERR.puts "[#{Time.local}] Warning: Cannot save header_theme_colors - feed not found: #{feed_url}"
        return
      end

      feed_id = existing
      begin
        @db.exec("UPDATE feeds SET header_theme_colors = ? WHERE id = ?", theme_json, feed_id)
        STDERR.puts "[#{Time.local}] Saved header_theme_colors for #{feed_url}"
      rescue ex
        STDERR.puts "[#{Time.local}] Error saving header_theme_colors for #{feed_url}: #{ex.message}"
      end
    end
  end

  # Retrieve stored theme-aware header colors JSON string for a feed
  def get_feed_theme_colors(feed_url : String) : String?
    @mutex.synchronize do
      normalized_url = normalize_feed_url(feed_url)
      result = @db.query_one?("SELECT header_theme_colors FROM feeds WHERE url = ?", normalized_url, as: {String?})

      if result.nil?
        result = @db.query_one?("SELECT header_theme_colors FROM feeds WHERE url = ?", feed_url, as: {String?})
      end

      result
    end
  end

  # Find feed URL by pattern (handles URL variations like with/without /feed suffix)
  def find_feed_url_by_pattern(url_pattern : String) : String?
    @mutex.synchronize do
      # Try exact match first
      result = @db.query_one?("SELECT url FROM feeds WHERE url = ?", url_pattern, as: {String?})
      return result if result

      # Try without /feed or /rss suffix
      normalized = url_pattern.rstrip('/').gsub(/\/rss(\.xml)?$/i, "").gsub(/\/feed(\.xml)?$/i, "")

      result = @db.query_one?("SELECT url FROM feeds WHERE url = ? OR url = ? OR url LIKE ? || '/%'",
        normalized,
        url_pattern,
        normalized) do |row|
        row.read(String?)
      end
      result
    end
  end

  # Get the total count of items for a specific feed URL from the database
  def item_count(url : String) : Int32
    @mutex.synchronize do
      result = @db.query_one?("SELECT COUNT(*) FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ?", url, as: {Int64})
      result ? result.to_i : 0
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

  # Check database file size and run aggressive cleanup if limit exceeded
  def check_size_limit(max_size_mb : Int32 = 100)
    @mutex.synchronize do
      return unless @db_path && File.exists?(@db_path)

      current_size_mb = File.size(@db_path).to_f64 / (1024 * 1024)

      if current_size_mb > max_size_mb
        STDERR.puts "[#{Time.local}] Database size (#{current_size_mb.round(2)}MB) exceeds limit (#{max_size_mb}MB), running aggressive cleanup..."

        # Run aggressive cleanup: delete older items first
        cutoff = (Time.utc - 3.days).to_s("%Y-%m-%d %H:%M:%S")
        result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
        deleted_count = result.rows_affected
        STDERR.puts "[#{Time.local}] Aggressive cleanup deleted #{deleted_count} old articles"

        # If still over limit, delete even more aggressively
        if File.size(@db_path).to_f64 / (1024 * 1024) > max_size_mb
          cutoff = (Time.utc - 1.day).to_s("%Y-%m-%d %H:%M:%S")
          result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
          deleted_count = result.rows_affected
          STDERR.puts "[#{Time.local}] Very aggressive cleanup deleted #{deleted_count} recent-old articles"
        end

        # Vacuum to reclaim space
        begin
          vacuum
          STDERR.puts "[#{Time.local}] Vacuumed database after size cleanup"
        rescue ex
          STDERR.puts "[#{Time.local}] Vacuum failed: #{ex.message}"
        end
      end
    end
  end

  # Sync favicon paths to ensure database points to local files
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

  # Ensure all performance indexes exist
  def ensure_indexes
    @mutex.synchronize do
      # Indexes for performance
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_feed_id ON items(feed_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_pub_date ON items(pub_date DESC)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_last_fetched ON feeds(last_fetched DESC)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_cluster ON items(cluster_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_lsh_band_search ON lsh_bands(band_index, band_hash)")
    end
  rescue ex
    # Ignore errors - indexes might already exist
  end

  # Run VACUUM to optimize the SQLite database file
  def vacuum
    @mutex.synchronize do
      begin
        STDERR.puts "[#{Time.local}] Running VACUUM on database"
        @db.exec("VACUUM")
        STDERR.puts "[#{Time.local}] VACUUM completed"
      rescue ex
        STDERR.puts "[#{Time.local}] VACUUM failed: #{ex.message}"
      end
    end
  end

  # Normalize pub_date values stored in the database.
  #
  # - Parses non-standard timestamp strings and rewrites them to
  #   the canonical UTC format "%Y-%m-%d %H:%M:%S".
  # - Leaves NULL pub_date values untouched (they are handled via
  #   COALESCE in queries so they sort last).
  #
  # This is safe to run repeatedly and is useful for fixing legacy
  # or imported feeds that stored dates in various formats.
  def normalize_pub_dates
    @mutex.synchronize do
      STDERR.puts "[#{Time.local}] Normalizing pub_date values..."

      # Collect id + pub_date values to process
      rows = [] of {Int64, String?}
      @db.query("SELECT id, pub_date FROM items WHERE pub_date IS NOT NULL") do |r|
        r.each do
          rows << {r.read(Int64), r.read(String?)}
        end
      end

      updated = 0
      rows.each do |id, raw|
        next if raw.nil?
        str = raw.not_nil!

        # If already in canonical form, skip quickly
        if str =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/
          next
        end

        parsed = nil.as(Time?)

        # Try a few common formats. If parsing fails, skip the row.
        begin
          begin
            parsed = Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
          rescue
          end

          if !parsed
            begin
              parsed = Time.parse(str, "%Y-%m-%dT%H:%M:%S%z", Time::Location::UTC)
            rescue
            end
          end

          if !parsed
            begin
              parsed = Time.parse(str, "%Y-%m-%dT%H:%M:%SZ", Time::Location::UTC)
            rescue
            end
          end

          if !parsed
            begin
              parsed = Time.parse(str, "%a, %d %b %Y %H:%M:%S %z", Time::Location::UTC)
            rescue
            end
          end
        rescue
          parsed = nil
        end

        if parsed
          formatted = parsed.to_s("%Y-%m-%d %H:%M:%S")
          if formatted != str
            @db.exec("UPDATE items SET pub_date = ? WHERE id = ?", formatted, id)
            updated += 1
          end
        end
      end

      STDERR.puts "[#{Time.local}] Normalized #{updated} pub_date rows"
    end
  rescue ex
    STDERR.puts "[#{Time.local}] Error normalizing pub_date: #{ex.message}"
  end

  # ============================================
  # Story Grouping / Clustering Methods
  # ============================================

  # Find all items excluding a specific item ID
  # Used for brute-force similarity comparison
  def find_all_items_excluding(item_id : Int64, limit : Int32 = 500) : Array(Int64)
    items = [] of Int64
    @mutex.synchronize do
      @db.query("SELECT id FROM items WHERE id != ? ORDER BY id DESC LIMIT ?", item_id, limit) do |rows|
        rows.each do
          items << rows.read(Int64)
        end
      end
    end
    items
  end

  # Find items by keywords (for paraphrase clustering)
  def find_by_keywords(keywords : Array(String), exclude_id : Int64, limit : Int32 = 100) : Array(Int64)
    return [] of Int64 if keywords.empty?

    items = [] of Int64
    placeholders = keywords.map { |_| "title LIKE ?" }.join(" OR ")
    sql = "SELECT DISTINCT id FROM items WHERE id != ? AND (#{placeholders}) ORDER BY id DESC LIMIT ?"

    args = [exclude_id] + keywords.map { |k| "%#{k}%" } + [limit]
    @db.query(sql, args: args) do |rows|
      rows.each do
        items << rows.read(Int64)
      end
    end
    items
  end

  # Assign an item to a cluster
  def assign_cluster(item_id : Int64, cluster_id : Int64?)
    @db.exec("UPDATE items SET cluster_id = ? WHERE id = ?", cluster_id, item_id)
  end

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
  def store_lsh_bands(item_id : Int64, band_hashes : Array(UInt64))
    @mutex.synchronize do
      begin
        @db.exec("BEGIN TRANSACTION")
        @db.exec("DELETE FROM lsh_bands WHERE item_id = ?", item_id)
        band_hashes.each_with_index do |band_hash, band_index|
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
  def find_lsh_candidates(signature : Array(UInt32)) : Array(Int64)
    bands = LexisMinhash::Engine.generate_bands(signature)
    candidates = Set(Int64).new

    @mutex.synchronize do
      bands.each do |band_index, band_hash|
        @db.query("SELECT DISTINCT item_id FROM lsh_bands WHERE band_index = ? AND band_hash = ?", band_index, band_hash.to_i64) do |rows|
          rows.each do
            item_id = rows.read(Int64)
            candidates << item_id
          end
        end
      end
    end

    candidates.to_a
  end

  # Clear clustering metadata (but keep feeds and items)
  def clear_clustering_metadata
    @mutex.synchronize do
      @db.exec("UPDATE items SET cluster_id = NULL")
      @db.exec("DELETE FROM lsh_bands")
      STDERR.puts "[#{Time.local}] Cleared clustering metadata"
    end
  end

  # Clear all cached data (feeds, items, clustering metadata)
  def clear_all
    @mutex.synchronize do
      @db.exec("DELETE FROM items")
      @db.exec("DELETE FROM feeds")
      @db.exec("DELETE FROM lsh_bands")
      STDERR.puts "[#{Time.local}] Cleared all cached data"
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

  # Get item title by ID (for clustering verification)
  def get_item_title(item_id : Int64) : String?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT title FROM items WHERE id = ?",
        item_id,
        as: String
      )
    end
  end

  # Get item feed_id by ID (for clustering - skip same-feed candidates)
  def get_item_feed_id(item_id : Int64) : Int64?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT feed_id FROM items WHERE id = ?",
        item_id,
        as: Int64
      )
    end
  end

  # Get feed_id by URL (for clustering)
  def get_feed_id(feed_url : String) : Int64?
    @mutex.synchronize do
      @db.query_one?(
        "SELECT id FROM feeds WHERE url = ?",
        feed_url,
        as: Int64
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
            id:           id,
            title:        title,
            link:         link,
            pub_date:     pub_date,
            feed_url:     feed_url,
            feed_title:   feed_title,
            favicon:      favicon,
            header_color: header_color,
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
            id:           id,
            title:        title,
            link:         link,
            pub_date:     pub_date,
            feed_url:     feed_url,
            feed_title:   feed_title,
            favicon:      favicon,
            header_color: header_color,
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
    result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
      {
        title:             row.read(String),
        url:               row.read(String),
        site_link:         row.read(String),
        header_color:      row.read(String?),
        header_text_color: row.read(String?),
        header_theme_colors: row.read(String?),
        etag:              row.read(String?),
        last_modified:     row.read(String?),
        favicon:           row.read(String?),
        favicon_data:      row.read(String?),
      }
    end

    return unless result

    # If favicon_data is nil but favicon is a local path, copy it
    if result[:favicon_data].nil?
      if favicon = result[:favicon]
        if favicon.starts_with?("/favicons/")
          result = {
            title:                result[:title],
            url:                  result[:url],
            site_link:            result[:site_link],
            header_color:         result[:header_color],
            header_text_color:    result[:header_text_color],
            header_theme_colors:  result[:header_theme_colors],
            etag:                 result[:etag],
            last_modified:        result[:last_modified],
            favicon:              result[:favicon],
            favicon_data:         favicon,
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

    fd = FeedData.new(
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
    fd.header_theme_colors = result[:header_theme_colors] if result[:header_theme_colors]
    fd
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

  # Ensure indexes exist (for existing databases that were created before indexes were added)
  cache.ensure_indexes

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
  cache.check_size_limit(DB_SIZE_HARD_LIMIT)

  # Vacuum if database is getting large (over 10MB)
  db_size = get_db_size(cache.db_path)
  if db_size > 10 * 1024 * 1024
    cache.vacuum
  end

  cache
end

# Save cache (SQLite auto-commits, but we vacuum occasionally)
def save_feed_cache(cache : FeedCache, retention_hours : Int32 = CACHE_RETENTION_HOURS, max_cache_size_mb : Int32 = 100)
  # Check database file size and run cleanup if exceeded
  cache.check_size_limit(max_cache_size_mb)

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

  # Periodically clean up old articles (7-day retention based on pub_date)
  if rand(100) < 10 # 10% chance to run cleanup
    cache.cleanup_old_articles(CACHE_RETENTION_DAYS)
  end

  # Sync favicon paths to ensure database points to local files
  cache.sync_favicon_paths
end

# Check if cache is fresh (within X minutes)
def cache_fresh?(last_fetched : Time, max_age_minutes : Int32 = 10) : Bool
  (Time.utc - last_fetched).total_minutes < max_age_minutes
end
