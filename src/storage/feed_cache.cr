require "db"
require "sqlite3"
require "mutex"
require "time"
require "openssl"
require "../config"
require "../models"
require "../result"
require "../errors"
require "../favicon_storage"
require "../color_extractor"
require "../health_monitor"
require "./cache_utils"
require "./database"
require "./clustering_repo"
require "./header_colors"
require "./cleanup"
require "../repositories/feed_repository"

class FeedCache
  include ClusteringRepository
  include HeaderColorsRepository
  include CleanupRepository

  @mutex : Mutex
  @db : DB::Database
  @db_path : String
  @feed_repository : Quickheadlines::Repositories::FeedRepository?

  def initialize(config : Config?, db : DB::Database? = nil)
    @mutex = Mutex.new
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)

    db_path = get_cache_db_path(config).as(String)
    @db_path = db_path

    @db = db || DB.open("sqlite3://#{@db_path}")
    create_schema(@db, @db_path)
    STDERR.puts "[#{Time.local}] Database initialized: #{@db_path}"

    log_db_size(@db_path, "on startup")
  end

  private def feed_repository : Quickheadlines::Repositories::FeedRepository
    @feed_repository ||= Quickheadlines::Repositories::FeedRepository.new(@db)
  end

  getter :db_path

  def add(feed_data : FeedData)
    feed_repository.upsert_with_items(feed_data)
  end

  def get(url : String) : FeedData?
    feed_repository.find_with_items(url)
  end

  def get_result(url : String) : FeedDataResult
    feed_repository.find_with_items_result(url)
  end

  def get_fetched_time(url : String) : Time?
    feed_repository.find_last_fetched_time(url)
  end

  def get_fetched_time_result(url : String) : TimeResult
    feed_repository.find_last_fetched_time_result(url)
  end

  def get_slice(url : String, limit : Int32, offset : Int32) : FeedData?
    feed_repository.find_with_items_slice(url, limit, offset)
  end

  def get_slice_result(url : String, limit : Int32, offset : Int32) : FeedDataResult
    feed_repository.find_with_items_slice_result(url, limit, offset)
  end

  def item_count(url : String) : Int32
    feed_repository.count_items(url)
  end

  def size : Int32
    feed_repository.count_all
  end

  def entries : Hash(String, FeedData)
    urls = {} of String => FeedData
    feed_repository.find_all_urls.each do |url|
      if feed = feed_repository.find_with_items(url)
        urls[url] = feed
      end
    end
    urls
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
    STDERR.puts "[#{Time.local}] Warning: ensure_indexes failed: #{ex.message}"
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
      STDERR.puts "[#{Time.local}] Warning: vacuum failed: #{ex.message}"
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
