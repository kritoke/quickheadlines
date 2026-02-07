require "db"
require "sqlite3"

# Database service for managing SQLite connections
# Provides dependency injection for database access
@[ADI::Register]
class DatabaseService
  @@instance : DatabaseService?

  getter db_path : String
  getter db : DB::Database

  def initialize(config : Config?)
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)

    @db_path = get_cache_db_path(config).as(String)
    @db = DB.open("sqlite3://#{@db_path}")
    create_schema(@db, @db_path)

    STDERR.puts "[#{Time.local}] DatabaseService initialized: #{@db_path}"
  end

  # Singleton access for backward compatibility
  def self.instance : DatabaseService
    @@instance ||= begin
      config = load_config_with_validation("feeds.yml").config
      DatabaseService.new(config)
    end
  end

  def self.instance=(service : DatabaseService)
    @@instance = service
  end

  # Helper method to get cache directory
  private def get_cache_dir(config : Config?) : String
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

  # Helper method to get database file path
  private def get_cache_db_path(config : Config?) : String
    File.join(get_cache_dir(config), "feed_cache.db")
  end

  # Helper method to ensure cache directory exists
  private def ensure_cache_dir(cache_dir : String)
    unless Dir.exists?(cache_dir)
      Dir.mkdir_p(cache_dir)
      STDERR.puts "[#{Time.local}] Created cache directory: #{cache_dir}"
    end
  end

  # Create database schema
  private def create_schema(db : DB::Database, db_path : String)
    # Enable WAL mode for improved concurrent access
    db.exec("PRAGMA journal_mode = WAL")

    # Set synchronous to NORMAL for better performance
    db.exec("PRAGMA synchronous = NORMAL")

    # Set cache size (64MB)
    db.exec("PRAGMA cache_size = -64000")

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
        favicon_data TEXT,
        last_fetched TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
      SQL

    # Add favicon_data column if needed (migration)
    begin
      db.exec("ALTER TABLE feeds ADD COLUMN favicon_data TEXT")
    rescue ex : SQLite3::Exception
      # Column already exists
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

    # Add columns if needed (migration)
    begin
      db.exec("ALTER TABLE items ADD COLUMN minhash_signature BLOB")
    rescue ex : SQLite3::Exception
      # Column already exists
    end

    begin
      db.exec("ALTER TABLE items ADD COLUMN cluster_id INTEGER REFERENCES items(id)")
    rescue ex : SQLite3::Exception
      # Column already exists
    end

    # LSH bands table
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
    db.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_items_unique_feed_link ON items(feed_id, link)")
  end

  def close
    @db.close
  end

  # Get timeline items from the last N days with cluster information
  def get_timeline_items(limit : Int32, offset : Int32, days_back : Int32?) : Array({id: Int64, title: String, link: String, pub_date: Time?, feed_title: String, feed_url: String, feed_link: String, favicon: String?, header_color: String?, header_text_color: String?, header_theme_colors: String?, cluster_id: Int64?, is_representative: Bool, cluster_size: Int32})
    items = [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_title: String, feed_url: String, feed_link: String, favicon: String?, header_color: String?, header_text_color: String?, header_theme_colors: String?, cluster_id: Int64?, is_representative: Bool, cluster_size: Int32}

    cutoff_clause = days_back ? "AND i.pub_date >= ?" : ""

    where_clause = <<-SQL
      FROM items i
      JOIN feeds f ON i.feed_id = f.id
      #{cutoff_clause}
      ORDER BY COALESCE(i.pub_date, '1970-01-01 00:00:00') DESC, i.id DESC
      LIMIT ? OFFSET ?
      SQL

    query = <<-SQL
      SELECT
        i.id,
        i.title,
        i.link,
        i.pub_date,
        f.title as feed_title,
        f.url as feed_url,
        f.site_link as feed_link,
        f.favicon,
        f.header_color,
        f.header_text_color,
        f.header_theme_colors,
        i.cluster_id,
        CASE WHEN i.id = (SELECT MIN(id) FROM items WHERE cluster_id = i.cluster_id AND cluster_id IS NOT NULL) THEN 1 ELSE 0 END as is_representative,
        (SELECT COUNT(*) FROM items WHERE cluster_id = i.cluster_id AND cluster_id IS NOT NULL) as cluster_size
      #{where_clause}
      SQL

    query_args = days_back ? [Time.local - days_back.days, limit, offset] : [limit, offset]

    @db.query(query, args: query_args) do |rows|
      rows.each do
        id = rows.read(Int64)
        title = rows.read(String)
        link = rows.read(String)
        pub_date_str = rows.read(String?)
        feed_title = rows.read(String)
        feed_url = rows.read(String)
        feed_link = rows.read(String)
        favicon = rows.read(String?)
        header_color = rows.read(String?)
        header_text_color = rows.read(String?)
        header_theme_colors = rows.read(String?)
        cluster_id = rows.read(Int64?)
        is_representative = rows.read(Int32) == 1
        cluster_size = rows.read(Int32)

        pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

        items << {
          id:                id,
          title:             title,
          link:              link,
          pub_date:          pub_date,
          feed_title:        feed_title,
          feed_url:          feed_url,
          feed_link:         feed_link,
          favicon:           favicon,
          header_color:      header_color,
          header_text_color: header_text_color,
          header_theme_colors: header_theme_colors,
          cluster_id:        cluster_id,
          is_representative: is_representative,
          cluster_size:      cluster_size,
        }
      end
    end

    items
  end

  # Count total timeline items in date range (nil days_back = no limit)
  def count_timeline_items(days_back : Int32?) : Int32
    if days_back
      cutoff_date = Time.local - days_back.days
      @db.query_one("SELECT COUNT(*) FROM items WHERE pub_date >= ?", cutoff_date, as: Int32)
    else
      @db.query_one("SELECT COUNT(*) FROM items", as: Int32)
    end
  end
end
