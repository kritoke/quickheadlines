require "db"
require "sqlite3"
require "mutex"
require "time"
require "openssl"
require "../config"
require "../models"
require "../favicon_storage"
require "../color_extractor"
require "../health_monitor"
require "./cache_utils"
require "./database"
require "./clustering_repo"
require "./header_colors"
require "./cleanup"

class FeedCache
  include ClusteringRepository
  include HeaderColorsRepository
  include CleanupRepository

  @mutex : Mutex
  @db : DB::Database
  @db_path : String

  def initialize(config : Config?)
    @mutex = Mutex.new
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)

    db_path = get_cache_db_path(config).as(String)
    @db_path = db_path

    @db = DB.open("sqlite3://#{@db_path}")
    create_schema(@db, @db_path)
    STDERR.puts "[#{Time.local}] Database initialized: #{@db_path}"

    log_db_size(@db_path, "on startup")
  end

  getter :db_path

  def add(feed_data : FeedData)
    @mutex.synchronize do
      begin
        @db.exec("BEGIN TRANSACTION")

        result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_data.url, as: {Int64})

        if result
          feed_id = result

          existing_color = @db.query_one?("SELECT header_color FROM feeds WHERE id = ?", feed_id, as: {String?})
          existing_text_color = @db.query_one?("SELECT header_text_color FROM feeds WHERE id = ?", feed_id, as: {String?})
          existing_theme = @db.query_one?("SELECT header_theme_colors FROM feeds WHERE id = ?", feed_id, as: {String?})

          header_color_to_save = feed_data.header_color.nil? ? existing_color : feed_data.header_color
          header_text_color_to_save = feed_data.header_text_color.nil? ? existing_text_color : feed_data.header_text_color
          header_theme_to_save = feed_data.header_theme_colors.nil? ? existing_theme : feed_data.header_theme_colors

          begin
            corrected = ColorExtractor.auto_correct_theme_json(header_theme_to_save, header_color_to_save, header_text_color_to_save)
            header_theme_to_save = corrected if corrected
          rescue
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
        else
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

        existing_titles = @db.query_all("SELECT title FROM items WHERE feed_id = ?", feed_id, as: String).to_set

        feed_data.items.each_with_index do |item, index|
          if existing_titles.includes?(item.title)
            next
          end

          pub_date_str = item.pub_date.try(&.to_s("%Y-%m-%d %H:%M:%S"))

          @db.exec(
            "INSERT OR IGNORE INTO items (feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?)",
            feed_id,
            item.title,
            item.link,
            pub_date_str,
            item.version,
            index
          )

          existing_titles << item.title

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
        end
      end
    end
  end

  def get(url : String) : FeedData?
    start_time = Time.monotonic
    feed_data = @mutex.synchronize do
      result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
        {
          title:               row.read(String),
          url:                 row.read(String),
          site_link:           row.read(String),
          header_color:        row.read(String?),
          header_text_color:   row.read(String?),
          header_theme_colors: row.read(String?),
          etag:                row.read(String?),
          last_modified:       row.read(String?),
          favicon:             row.read(String?),
          favicon_data:        row.read(String?),
        }
      end

      unless result
        HealthMonitor.record_cache_miss
        return
      end
      HealthMonitor.record_cache_hit

      if result[:favicon_data].nil?
        if favicon = result[:favicon]
          if favicon.starts_with?("/favicons/")
            result = {
              title:               result[:title],
              url:                 result[:url],
              site_link:           result[:site_link],
              header_color:        result[:header_color],
              header_text_color:   result[:header_text_color],
              header_theme_colors: result[:header_theme_colors],
              etag:                result[:etag],
              last_modified:       result[:last_modified],
              favicon:             result[:favicon],
              favicon_data:        favicon,
            }
          end
        end
      end

      feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: {Int64})
      return unless feed_id_result
      feed_id = feed_id_result

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
    query_time = (Time.monotonic - start_time).total_milliseconds
    HealthMonitor.record_db_query(query_time)
    feed_data
  end

  def get_fetched_time(url : String) : Time?
    @mutex.synchronize do
      result = @db.query_one?("SELECT last_fetched FROM feeds WHERE url = ?", url, as: {String})
      return unless result

      Time.parse(result, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
    end
  end

  def get_slice(url : String, limit : Int32, offset : Int32) : FeedData?
    @mutex.synchronize do
      feed_result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
        {
          title:               row.read(String),
          url:                 row.read(String),
          site_link:           row.read(String),
          header_color:        row.read(String?),
          header_text_color:   row.read(String?),
          header_theme_colors: row.read(String?),
          etag:                row.read(String?),
          last_modified:       row.read(String?),
          favicon:             row.read(String?),
          favicon_data:        row.read(String?),
        }
      end
      return unless feed_result

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

  def item_count(url : String) : Int32
    @mutex.synchronize do
      result = @db.query_one?("SELECT COUNT(*) FROM items JOIN feeds ON items.feed_id = feeds.id WHERE feeds.url = ?", url, as: {Int64})
      result ? result.to_i : 0
    end
  end

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

  def size : Int32
    @mutex.synchronize do
      result = @db.query_one?("SELECT COUNT(*) FROM feeds", as: {Int64})
      result ? result.to_i : 0
    end
  end

  def sync_favicon_paths
    @mutex.synchronize do
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

      feeds_data.each do |feed_id, url, favicon, favicon_data|
        if favicon_data && favicon_data.starts_with?("http")
          @db.exec("UPDATE feeds SET favicon_data = NULL WHERE id = ?", feed_id)
          STDERR.puts "[Cache] Cleared external URL from favicon_data for #{url}: #{favicon_data}"
          favicon_data = nil
        end

        if favicon_data.nil? && favicon.starts_with?("/favicons/")
          @db.exec("UPDATE feeds SET favicon_data = ? WHERE id = ?", favicon, feed_id)
          STDERR.puts "[Cache] Synced favicon_data for #{url}: #{favicon}"
        end

        if favicon.starts_with?("http")
          hash = OpenSSL::Digest.new("SHA256").update(favicon).final.hexstring
          possible_extensions = ["png", "jpg", "jpeg", "ico", "svg", "webp"]

          found_local = false
          possible_extensions.each do |ext|
            filename = "#{hash[0...16]}.#{ext}"
            filepath = File.join(FaviconStorage::FAVICON_DIR, filename)
            if File.exists?(filepath)
              local_path = "/favicons/#{filename}"
              @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", local_path, local_path, feed_id)
              STDERR.puts "[Cache] Synced favicon for #{url}: #{favicon} -> #{local_path}"
              found_local = true
              break
            end
          end

          unless found_local
            @db.exec("UPDATE feeds SET favicon = NULL, favicon_data = NULL WHERE id = ?", feed_id)
            STDERR.puts "[Cache] Cleared missing favicon for #{url}: #{favicon}"
          end
        end
      end
    end
  end

  def ensure_indexes
    @mutex.synchronize do
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_feed_id ON items(feed_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_pub_date ON items(pub_date DESC)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_last_fetched ON feeds(last_fetched DESC)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_cluster ON items(cluster_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_lsh_band_search ON lsh_bands(band_index, band_hash)")
    end
  rescue ex
  end

  def clear_all
    @mutex.synchronize do
      @db.exec("DELETE FROM items")
      @db.exec("DELETE FROM feeds")
      @db.exec("DELETE FROM lsh_bands")
      STDERR.puts "[#{Time.local}] Cleared all cached data"
    end
  end

  def db : DB::Database
    @db
  end

  def close
    @mutex.synchronize do
      @db.close
    end
  end

  private def get_without_lock(url : String) : FeedData?
    result = @db.query_one?("SELECT title, url, site_link, header_color, header_text_color, header_theme_colors, etag, last_modified, favicon, favicon_data FROM feeds WHERE url = ?", url) do |row|
      {
        title:               row.read(String),
        url:                 row.read(String),
        site_link:           row.read(String),
        header_color:        row.read(String?),
        header_text_color:   row.read(String?),
        header_theme_colors: row.read(String?),
        etag:                row.read(String?),
        last_modified:       row.read(String?),
        favicon:             row.read(String?),
        favicon_data:        row.read(String?),
      }
    end

    return unless result

    if result[:favicon_data].nil?
      if favicon = result[:favicon]
        if favicon.starts_with?("/favicons/")
          result = {
            title:               result[:title],
            url:                 result[:url],
            site_link:           result[:site_link],
            header_color:        result[:header_color],
            header_text_color:   result[:header_text_color],
            header_theme_colors: result[:header_theme_colors],
            etag:                result[:etag],
            last_modified:       result[:last_modified],
            favicon:             result[:favicon],
            favicon_data:        favicon,
          }
        end
      end
    end

    feed_id_result = @db.query_one?("SELECT id FROM feeds WHERE url = ?", url, as: {Int64})
    return unless feed_id_result
    feed_id = feed_id_result

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

def load_feed_cache(config : Config?) : FeedCache
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path : String = get_cache_db_path(config)

  init_db(config) unless File.exists?(db_path)

  health_status = DbHealthStatus::Healthy
  if File.exists?(db_path)
    health_status = check_db_health(db_path)

    case health_status
    when DbHealthStatus::Corrupted
      STDERR.puts "[ERROR] Database corruption detected, attempting repair..."
      repair_result = repair_database(config)

      if repair_result.status == DbHealthStatus::Repaired
        STDERR.puts "[#{Time.local}] Database was previously repaired"
      end
    end
  end

  cache = FeedCache.new(config)

  cache.ensure_indexes

  cache.sync_favicon_paths

  if health_status == DbHealthStatus::Healthy
    cache.cleanup_old_articles(CACHE_RETENTION_DAYS)
  end

  retention_hours = config.try(&.cache_retention_hours) || CACHE_RETENTION_HOURS

  config_urls = config.try do |c|
    urls = c.feeds.map(&.url)
    c.tabs.each do |tab|
      urls.concat(tab.feeds.map(&.url))
    end
    urls
  end

  cache.cleanup_old_entries(retention_hours, config_urls)

  cache.check_size_limit(DB_SIZE_HARD_LIMIT)

  db_size = get_db_size(cache.db_path)
  if db_size > 10 * 1024 * 1024
    cache.vacuum
  end

  cache
end

def save_feed_cache(cache : FeedCache, retention_hours : Int32 = CACHE_RETENTION_HOURS, max_cache_size_mb : Int32 = 100)
  cache.check_size_limit(max_cache_size_mb)

  if rand(100) < 5
    begin
      cache.vacuum
    rescue ex
    end
  end

  if rand(100) < 10
    cache.cleanup_old_entries(retention_hours)
  end

  if rand(100) < 10
    cache.cleanup_old_articles(CACHE_RETENTION_DAYS)
  end

  cache.sync_favicon_paths
end

def cache_fresh?(last_fetched : Time, max_age_minutes : Int32 = 10) : Bool
  (Time.utc - last_fetched).total_minutes < max_age_minutes
end
