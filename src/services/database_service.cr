require "db"
require "sqlite3"
require "mutex"
require "../config"
require "../storage/schema"
require "../storage/cache_utils"
require "../storage/database"

class DatabaseService
  @@instance : DatabaseService?
  @@instance_mutex = Mutex.new

  getter db_path : String
  getter db : DB::Database

  def initialize(config : Config)
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)

    @db_path = get_cache_db_path(config).as(String)

    @db = DB.open("sqlite3://#{@db_path}?busy_timeout=#{QuickHeadlines::Constants::SQLITE_BUSY_TIMEOUT_MS}&max_pool_size=#{QuickHeadlines::Constants::DB_MAX_POOL_SIZE}")
    ::create_schema(@db, @db_path)

    Log.for("quickheadlines.storage").info { "DatabaseService initialized: #{@db_path}" }
  end

  def self.instance : DatabaseService
    @@instance_mutex.synchronize do
      @@instance ||= begin
        raise "DatabaseService: Not initialized. AppBootstrap must create DatabaseService before accessing instance."
      end
    end
  end

  def self.instance=(service : DatabaseService)
    @@instance_mutex.synchronize { @@instance = service }
  end

  def close
    @db.close
  end
end
