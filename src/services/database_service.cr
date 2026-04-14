require "db"
require "sqlite3"
require "../config"
require "../storage/schema"
require "../storage/cache_utils"
require "./app_bootstrap"

# Forward declaration - will be defined in application.cr
module QuickHeadlines
  class Application
    class_property initial_config : Config? = nil
    class_property bootstrap : AppBootstrap? = nil
  end
end

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
    @db = DB.open("sqlite3://#{@db_path}?busy_timeout=5000")
    create_schema(@db, @db_path)

    Log.for("quickheadlines.storage").info { "DatabaseService initialized: #{@db_path}" }
  end

  # Singleton access for backward compatibility
  def self.instance : DatabaseService
    @@instance ||= begin
      config = QuickHeadlines::Application.initial_config
      if config.nil?
        raise "DatabaseService: Configuration not initialized"
      end
      DatabaseService.new(config)
    end
  end

  def self.instance=(service : DatabaseService)
    @@instance = service
  end

  # Helper method to get cache directory
  private def get_cache_dir(config : Config?) : String
    ::get_cache_dir(config)
  end

  # Helper method to get database file path
  private def get_cache_db_path(config : Config?) : String
    ::get_cache_db_path(config)
  end

  # Helper method to ensure cache directory exists
  private def ensure_cache_dir(cache_dir : String)
    ::ensure_cache_dir(cache_dir)
  end

  # Create database schema
  private def create_schema(db : DB::Database, db_path : String)
    db.exec("PRAGMA journal_mode = WAL")
    db.exec("PRAGMA synchronous = NORMAL")
    db.exec("PRAGMA cache_size = -64000")
    db.exec("PRAGMA foreign_keys = ON")
    db.exec("PRAGMA mmap_size = 0")
    db.exec("PRAGMA wal_autocheckpoint = 20")

    db.exec(Schema::FEEDS_TABLE)
    db.exec(Schema::ITEMS_TABLE)
    db.exec(Schema::LSH_BANDS_TABLE)
    db.exec(Schema::INDEXES)

    run_migrations(db)
  end

  def close
    @db.close
  end
end
