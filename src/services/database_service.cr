require "db"
require "sqlite3"
require "mutex"
require "../config"
require "../storage/schema"
require "../storage/cache_utils"
require "../storage/database"
require "../infrastructure/singleton"

class DatabaseService
  def_singleton_manual("DatabaseService: Not initialized. AppBootstrap must create DatabaseService before accessing instance.")

  getter db_path : String
  getter db : DB::Database

  def initialize(config : Config)
    cache_dir = QuickHeadlines::CacheUtils.get_cache_dir(config)
    QuickHeadlines::CacheUtils.ensure_cache_dir(cache_dir)

    @db_path = QuickHeadlines::CacheUtils.get_cache_db_path(config).as(String)

    @db = DB.open("sqlite3://#{@db_path}?busy_timeout=#{QuickHeadlines::Constants::SQLITE_BUSY_TIMEOUT_MS}&max_pool_size=#{QuickHeadlines::Constants::DB_MAX_POOL_SIZE}")
    Database.create_schema(@db, @db_path)
  end

  def close
    # Drain any pending DB operations by closing gracefully.
    # Using a non-blocking close ensures senders don't get ClosedError.

    @db.close
  rescue ex : DB::Error | IO::Error
    Log.for("quickheadlines.db").warn { "Database close error: #{ex.message}" }
  end
end
