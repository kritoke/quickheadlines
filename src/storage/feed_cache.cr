require "db"
require "sqlite3"
require "mutex"
require "time"
require "../module"
require "../config"
require "../constants"
require "../models"
require "../services/database_service"
require "../services/favicon_sync_service"
require "./cache_utils"
require "./database"
require "./clustering_store"
require "./header_color_store"
require "./cleanup_store"
require "../repositories/feed_repository"

class FeedCache
  @@instance : FeedCache?

  def self.instance : FeedCache
    @@instance || raise "FeedCache: Not initialized. AppBootstrap must create FeedCache before accessing instance."
  end

  def self.instance=(cache : FeedCache)
    @@instance = cache
  end

  @mutex : Mutex
  @db_service : DatabaseService
  @db : DB::Database
  @db_path : String
  @feed_repository : QuickHeadlines::Repositories::FeedRepository?
  @clustering_store : QuickHeadlines::Storage::ClusteringStore
  @header_color_store : QuickHeadlines::Storage::HeaderColorStore
  @cleanup_store : QuickHeadlines::Storage::CleanupStore

  def initialize(config : Config, @db_service : DatabaseService)
    @mutex = Mutex.new
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)

    @db_path = get_cache_db_path(config).as(String)
    @db = @db_service.db

    @clustering_store = QuickHeadlines::Storage::ClusteringStore.new(@db, @mutex)
    @header_color_store = QuickHeadlines::Storage::HeaderColorStore.new(@db, @mutex)
    @cleanup_store = QuickHeadlines::Storage::CleanupStore.new(@db, @mutex, @db_path)

    Log.for("quickheadlines.storage").info { "Database initialized: #{@db_path}" }

    log_db_size(@db_path, "on startup")

    # Ensure WAL is checkpointed at startup to prevent unbounded growth
    @cleanup_store.ensure_wal_checkpoint
  end

  private def feed_repository : QuickHeadlines::Repositories::FeedRepository
    @feed_repository ||= QuickHeadlines::Repositories::FeedRepository.new(@db_service)
  end

  getter :clustering_store, :header_color_store, :cleanup_store, :db_service

  def get_item_signature(item_id : Int64) : Array(UInt32)?
    @clustering_store.get_item_signature(item_id)
  end

  def get_item_feed_id(item_id : Int64) : Int64?
    @clustering_store.get_item_feed_id(item_id)
  end

  def get_item_title(item_id : Int64) : String?
    @clustering_store.get_item_title(item_id)
  end

  def get_cluster_items(cluster_id : Int64) : Array(Int64)
    @clustering_store.get_cluster_items(cluster_id)
  end

  def assign_cluster(item_id : Int64, cluster_id : Int64?)
    @clustering_store.assign_cluster(item_id, cluster_id)
  end

  def store_lsh_bands(item_id : Int64, band_hashes : Array(UInt64))
    @clustering_store.store_lsh_bands(item_id, band_hashes)
  end

  def find_lsh_candidates(signature : Array(UInt32)) : Array(Int64)
    @clustering_store.find_lsh_candidates(signature)
  end

  def assign_clusters_bulk(clusters : Hash(Int64, Array(Int64)))
    @clustering_store.assign_clusters_bulk(clusters)
  end

  def clear_clustering_metadata
    @clustering_store.clear_clustering_metadata
  end

  def get_feed_id(feed_url : String) : Int64?
    @clustering_store.get_feed_id(feed_url)
  end

  def get_item_ids_batch(items : Array(QuickHeadlines::Storage::ClusteringStore::ItemKey)) : Hash(String, Int64)
    @clustering_store.get_item_ids_batch(items)
  end

  def get_cluster_items_full(cluster_id : Int64) : Array(ClusteringItemRow)
    @clustering_store.get_cluster_items_full(cluster_id)
  end

  def store_item_signature(item_id : Int64, signature : Array(UInt32))
    @clustering_store.store_item_signature(item_id, signature)
  end

  def update_header_colors(feed_url : String, bg_color : String, text_color : String)
    @header_color_store.update_header_colors(feed_url, bg_color, text_color)
  end

  def get_header_colors(feed_url : String) : {bg_color: String?, text_color: String?}
    @header_color_store.get_header_colors(feed_url)
  end

  def load_theme(feed_url : String) : String?
    @header_color_store.load_theme(feed_url)
  end

  def find_url_by_pattern(url_pattern : String) : String?
    @header_color_store.find_url_by_pattern(url_pattern)
  end

  def cleanup_old_entries(retention_hours : Int32 = QuickHeadlines::Constants::CACHE_RETENTION_HOURS, config_urls : Array(String)? = nil)
    @cleanup_store.cleanup_old_entries(retention_hours, config_urls)
  end

  def cleanup_old_articles(retention_days : Int32 = QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
    @cleanup_store.cleanup_old_articles(retention_days)
  end

  def remove_stale_feeds(config_urls : Array(String))
    @cleanup_store.remove_stale_feeds(config_urls)
  end

  def check_size_limit(max_size_mb : Int32 = 100)
    @cleanup_store.check_size_limit(max_size_mb)
  end

  def vacuum
    @cleanup_store.vacuum
  end

  def normalize_pub_dates
    @cleanup_store.normalize_pub_dates
  end

  getter :db_path

  def add(feed_data : FeedData)
    feed_repository.upsert_with_items(feed_data)
  end

  def get(url : String) : FeedData?
    feed_repository.find_with_items(url)
  end

  def get_fetched_time(url : String) : Time?
    feed_repository.find_last_fetched_time(url)
  end

  def item_count(url : String) : Int32
    feed_repository.count_items(url)
  end

  def size : Int32
    feed_repository.count_all
  end

  def ensure_indexes
    @mutex.synchronize do
      @db.exec(Schema::INDEXES)
    end
  rescue ex
    Log.for("quickheadlines.storage").warn { "ensure_indexes failed: #{ex.message}" }
  end

  def clear_all
    @mutex.synchronize do
      @db.transaction do
        @db.exec("DELETE FROM items")
        @db.exec("DELETE FROM feeds")
        @db.exec("DELETE FROM lsh_bands")
      end
      Log.for("quickheadlines.storage").info { "Cleared all cached data" }
    end
  end

  def db : DB::Database
    @db
  end
end

def load_feed_cache(config : Config, db_service : DatabaseService) : FeedCache
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path : String = get_cache_db_path(config)

  init_db(config) unless File.exists?(db_path)

  health_status = DbHealthStatus::Healthy
  if File.exists?(db_path)
    health_status = check_db_health(db_path)

    case health_status
    when DbHealthStatus::Corrupted
      Log.for("quickheadlines.storage").error { "Database corruption detected, attempting repair..." }
      repair_result = repair_database(config)

      if repair_result.status == DbHealthStatus::Repaired
        Log.for("quickheadlines.storage").info { "Database was previously repaired" }
      end
    end
  end

  cache = FeedCache.new(config, db_service)

  cache.ensure_indexes

  if health_status == DbHealthStatus::Healthy
    cache.cleanup_old_articles(QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
  end

  retention_hours = config.try(&.cache_retention_hours) || QuickHeadlines::Constants::CACHE_RETENTION_HOURS

  config_urls = config.try(&.all_feed_urls)

  cache.cleanup_old_entries(retention_hours, config_urls)

  cache.check_size_limit(QuickHeadlines::Constants::DB_SIZE_HARD_LIMIT)

  cache
end

module QuickHeadlines::Storage
  @@last_cache_cleanup = Time.utc

  def self.last_cache_cleanup=(value : Time)
    @@last_cache_cleanup = value
  end

  def self.last_cache_cleanup
    @@last_cache_cleanup
  end
end

def save_feed_cache(cache : FeedCache, retention_hours : Int32 = QuickHeadlines::Constants::CACHE_RETENTION_HOURS, max_cache_size_mb : Int32 = 100)
  cache.check_size_limit(max_cache_size_mb)

  now = Time.utc
  if now - QuickHeadlines::Storage.last_cache_cleanup >= 1.hour
    begin
      cache.vacuum
    rescue ex
      Log.for("quickheadlines.storage").warn { "vacuum failed: #{ex.message}" }
    end

    # Ensure WAL is truncated after vacuum to reclaim disk space
    cache.cleanup_store.ensure_wal_checkpoint

    cache.cleanup_old_entries(retention_hours)
    cache.cleanup_old_articles(QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
    QuickHeadlines::Storage.last_cache_cleanup = now
  end

  FaviconSyncService.new(cache.db).sync_favicon_paths
end
