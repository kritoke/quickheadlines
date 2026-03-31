require "athena"
require "db"
require "sqlite3"
require "mutex"
require "time"
require "../config"
require "../constants"
require "../models"
require "../result"
require "../errors"
require "../services/database_service"
require "../services/favicon_sync_service"
require "./cache_utils"
require "./database"
require "./clustering_repo"
require "./header_colors"
require "./cleanup"
require "../repositories/feed_repository"

@[ADI::Register]
class FeedCache
  include ClusteringRepository
  include HeaderColorsRepository
  include CleanupRepository

  @mutex : Mutex
  @db_service : DatabaseService?
  @db : DB::Database
  @db_path : String
  @feed_repository : QuickHeadlines::Repositories::FeedRepository?

  def initialize(config : Config?, @db_service : DatabaseService? = nil)
    @mutex = Mutex.new
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)

    @db_path = get_cache_db_path(config).as(String)

    unless @db_service
      @db_service = begin
        DatabaseService.instance
      rescue
        nil
      end
    end

    if @db_service
      @db = @db_service.not_nil!.db
    else
      @db = DB.open("sqlite3://#{@db_path}")
    end

    create_schema(@db, @db_path)
    STDERR.puts "[#{Time.local}] Database initialized: #{@db_path}"

    log_db_size(@db_path, "on startup")
  end

  private def feed_repository : QuickHeadlines::Repositories::FeedRepository
    @feed_repository ||= QuickHeadlines::Repositories::FeedRepository.new(@db_service || @db)
  end

  getter :db_path

  def db_service : DatabaseService?
    @db_service
  end

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
    @mutex.synchronize do
      urls = {} of String => FeedData
      feed_repository.find_all_urls.each do |url|
        if feed = feed_repository.find_with_items(url)
          urls[url] = feed
        end
      end
      urls
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
      # Composite indexes for timeline query optimization
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_timeline ON items(pub_date DESC, id DESC, cluster_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_cluster_rep ON items(cluster_id, id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_feed_timeline ON items(feed_id, pub_date DESC, id DESC)")
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

  FaviconSyncService.new(cache.db).sync_favicon_paths

  if health_status == DbHealthStatus::Healthy
    cache.cleanup_old_articles(Constants::CACHE_RETENTION_DAYS)
  end

  retention_hours = config.try(&.cache_retention_hours) || Constants::CACHE_RETENTION_HOURS

  config_urls = config.try do |conf|
    urls = conf.feeds.map(&.url)
    conf.tabs.each do |tab|
      urls.concat(tab.feeds.map(&.url))
    end
    urls
  end

  cache.cleanup_old_entries(retention_hours, config_urls)

  cache.check_size_limit(Constants::DB_SIZE_HARD_LIMIT)

  db_size = get_db_size(cache.db_path)
  if db_size > 10 * 1024 * 1024
    cache.vacuum
  end

  cache
end

def save_feed_cache(cache : FeedCache, retention_hours : Int32 = Constants::CACHE_RETENTION_HOURS, max_cache_size_mb : Int32 = 100)
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
    cache.cleanup_old_articles(Constants::CACHE_RETENTION_DAYS)
  end

  FaviconSyncService.new(cache.db).sync_favicon_paths
end

def cache_fresh?(last_fetched : Time, max_age_minutes : Int32 = 10) : Bool
  (Time.utc - last_fetched).total_minutes < max_age_minutes
end
