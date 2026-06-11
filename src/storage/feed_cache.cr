require "db"
require "../models"
require "sqlite3"
require "mutex"
require "time"
require "../module"
require "../config"
require "../constants"
require "../services/database_service"
require "./cache_utils"
require "./database"
require "./clustering_store"
require "./header_color_store"
require "./cleanup_store"
require "../repositories/feed_repository"

class FeedCache
  @@instance : FeedCache?
  @@instance_mutex = Mutex.new(:unchecked)

  def self.instance : FeedCache
    @@instance_mutex.synchronize do
      @@instance || raise "FeedCache: Not initialized. AppBootstrap must create FeedCache before accessing instance."
    end
  end

  def self.instance=(cache : FeedCache)
    @@instance_mutex.synchronize { @@instance = cache }
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
    cache_dir = QuickHeadlines::CacheUtils.get_cache_dir(config)
    QuickHeadlines::CacheUtils.ensure_cache_dir(cache_dir)

    @db_path = QuickHeadlines::CacheUtils.get_cache_db_path(config).as(String)
    @db = @db_service.db

    @clustering_store = QuickHeadlines::Storage::ClusteringStore.new(@db)
    @header_color_store = QuickHeadlines::Storage::HeaderColorStore.new(@db)
    @cleanup_store = QuickHeadlines::Storage::CleanupStore.new(@db, @mutex, @db_path)

    Log.for("quickheadlines.storage").info { "Database initialized: #{@db_path}" }

    QuickHeadlines::CacheUtils.log_db_size(@db_path, "on startup")

    # Ensure WAL is checkpointed at startup to prevent unbounded growth
    @cleanup_store.ensure_wal_checkpoint
  end

  private def feed_repository : QuickHeadlines::Repositories::FeedRepository
    @feed_repository ||= QuickHeadlines::Repositories::FeedRepository.new(@db_service)
  end

  getter :clustering_store, :header_color_store, :cleanup_store, :db_service

  getter :clustering_store, :header_color_store, :cleanup_store, :db_service

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

  # Batch count items for multiple feed URLs in a single query.
  def item_counts(urls : Array(String)) : Hash(String, Int32)
    feed_repository.count_items_batch(urls)
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

  def self.load(config : Config, db_service : DatabaseService) : FeedCache
    cache_dir = QuickHeadlines::CacheUtils.get_cache_dir(config)
    QuickHeadlines::CacheUtils.ensure_cache_dir(cache_dir)
    db_path : String = QuickHeadlines::CacheUtils.get_cache_db_path(config)

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
      cache.cleanup_store.cleanup_old_articles(QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
    end

    retention_hours = config.try(&.cache_retention_hours) || QuickHeadlines::Constants::CACHE_RETENTION_HOURS

    config_urls = config.try(&.all_feed_urls)

    cache.cleanup_store.cleanup_old_entries(retention_hours, config_urls)

    cache.cleanup_store.check_size_limit(QuickHeadlines::Constants::DB_SIZE_HARD_LIMIT)

    cache
  end

  def save(retention_hours : Int32 = QuickHeadlines::Constants::CACHE_RETENTION_HOURS, max_cache_size_mb : Int32 = 100) : Nil
    @cleanup_store.check_size_limit(max_cache_size_mb)

    # Always checkpoint WAL to prevent unbounded growth
    # WAL can grow significantly between vacuum cycles (refresh runs every 30 min)
    # Checkpoint is cheap (just syncing WAL to main db), so do it every time
    @cleanup_store.ensure_wal_checkpoint

    now = Time.utc
    if now - QuickHeadlines::Storage.last_cache_cleanup >= 1.hour
      # Retry logic for VACUUM in case of temporary database locks
      max_retries = 3
      retry_delay = 5 # seconds between retries
      vacuum_succeeded = false

      max_retries.times do |attempt|
        begin
          @cleanup_store.vacuum
          vacuum_succeeded = true
          break
        rescue ex : Exception
          if ex.message.try(&.includes?("database is locked")) || ex.message.try(&.includes?("database locked"))
            if attempt < max_retries - 1
              Log.for("quickheadlines.storage").warn { "VACUUM locked (attempt #{attempt + 1}/#{max_retries}), retrying in #{retry_delay}s" }
              sleep(retry_delay.seconds)
            else
              Log.for("quickheadlines.storage").warn { "VACUUM skipped - database locked after #{max_retries} attempts" }
            end
          else
            Log.for("quickheadlines.storage").warn { "vacuum failed: #{ex.message}" }
            break
          end
        end
      end

      @cleanup_store.cleanup_old_entries(retention_hours)
      @cleanup_store.cleanup_old_articles(QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
      QuickHeadlines::Storage.last_cache_cleanup = now
    end
  end
end
