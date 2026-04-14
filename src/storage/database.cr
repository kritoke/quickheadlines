require "db"
require "sqlite3"
require "../config"
require "./cache_utils"
require "./schema"

struct DatabaseMigration
  property version : Int32
  property name : String
  property up : DB::Database -> Nil

  def initialize(@version : Int32, @name : String, &@up : DB::Database -> Nil)
  end
end

private def column_exists?(db : DB::Database, table : String, column : String) : Bool
  db.query_one?("SELECT 1 FROM pragma_table_info(?) WHERE name = ?", table, column, as: Bool) || false
rescue
  false
end

private def ensure_column(db : DB::Database, table : String, column : String, type : String) : Nil
  return if column_exists?(db, table, column)
  db.exec("ALTER TABLE #{table} ADD COLUMN #{column} #{type}")
end

MIGRATIONS = [
  DatabaseMigration.new(version: 1, name: "add_favicon_data_column") do |db|
    ensure_column(db, "feeds", "favicon_data", "TEXT")
  end,
  DatabaseMigration.new(version: 2, name: "add_header_text_color_column") do |db|
    ensure_column(db, "feeds", "header_text_color", "TEXT")
  end,
  DatabaseMigration.new(version: 3, name: "add_header_theme_colors_column") do |db|
    ensure_column(db, "feeds", "header_theme_colors", "TEXT")
  end,
  DatabaseMigration.new(version: 4, name: "add_minhash_signature_column") do |db|
    ensure_column(db, "items", "minhash_signature", "BLOB")
  end,
  DatabaseMigration.new(version: 5, name: "add_cluster_id_column") do |db|
    ensure_column(db, "items", "cluster_id", "INTEGER REFERENCES items(id)")
  end,
  DatabaseMigration.new(version: 6, name: "migrate_lsh_bands_to_text") do |db|
    raw_value = db.query_one?("SELECT band_hash FROM lsh_bands LIMIT 1", as: {String?})
    if raw_value && raw_value.to_i64?
      db.exec("DROP TABLE lsh_bands")
    end
  end,
  DatabaseMigration.new(version: 7, name: "add_comment_url_and_commentary_url_columns") do |db|
    ensure_column(db, "items", "comment_url", "TEXT")
    ensure_column(db, "items", "commentary_url", "TEXT")
  end,
]

private def ensure_schema_info_table(db : DB::Database) : Nil
  db.exec("CREATE TABLE IF NOT EXISTS schema_info (version INTEGER PRIMARY KEY)")
  current = db.query_one?("SELECT version FROM schema_info LIMIT 1", as: {Int32?})
  unless current
    db.exec("INSERT INTO schema_info (version) VALUES (0)")
  end
end

private def get_schema_version(db : DB::Database) : Int32
  db.query_one("SELECT version FROM schema_info LIMIT 1", as: {Int32})
end

private def set_schema_version(db : DB::Database, version : Int32) : Nil
  db.exec("UPDATE schema_info SET version = ?", version)
end

def run_migrations(db : DB::Database) : Nil
  ensure_schema_info_table(db)
  current_version = get_schema_version(db)

  MIGRATIONS.each do |migration|
    next if migration.version <= current_version

    Log.for("quickheadlines.storage").info { "Running migration #{migration.version}: #{migration.name}" }
    begin
      migration.up.call(db)
    rescue ex : Exception
      Log.for("quickheadlines.storage").error(exception: ex) { "Migration #{migration.version} (#{migration.name}) failed" }
      raise ex
    end
    set_schema_version(db, migration.version)
    Log.for("quickheadlines.storage").debug { "Migration #{migration.version} applied (new version: #{migration.version})" }
  end
end

def create_schema(db : DB::Database, db_path : String)
  db.exec("PRAGMA journal_mode = WAL")
  db.exec("PRAGMA synchronous = NORMAL")
  db.exec("PRAGMA cache_size = -64000")
  db.exec("PRAGMA foreign_keys = ON")
  db.exec("PRAGMA mmap_size = 0")
  db.exec("PRAGMA wal_autocheckpoint = 100")

  db.exec(Schema::FEEDS_TABLE)
  db.exec(Schema::ITEMS_TABLE)
  db.exec(Schema::LSH_BANDS_TABLE)

  run_migrations(db)

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
    Log.for("quickheadlines.storage").debug { "Cleaned up #{cleanup_result.rows_affected} duplicate items from database" }
  end

  db.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_items_unique_feed_link ON items(feed_id, link)")
end

def check_db_integrity(db_path : String) : Bool
  DB.open("sqlite3://#{db_path}") do |database|
    result = database.query_one("PRAGMA integrity_check", as: {String})
    if result == "ok"
      Log.for("quickheadlines.storage").debug { "Database integrity check passed" }
      true
    else
      Log.for("quickheadlines.storage").error { "Database integrity check failed: #{result}" }
      false
    end
  end
rescue ex : Exception
  Log.for("quickheadlines.storage").error(exception: ex) { "Database integrity check failed" }
  false
end

def check_db_health(db_path : String) : DbHealthStatus
  unless File.exists?(db_path)
    return DbHealthStatus::NeedsRepopulation
  end

  if File.size(db_path) < QuickHeadlines::Constants::MIN_DB_SIZE_BYTES
    Log.for("quickheadlines.storage").warn { "Database file is too small (#{File.size(db_path)} bytes), may be empty" }
    return DbHealthStatus::NeedsRepopulation
  end

  DB.open("sqlite3://#{db_path}") do |database|
    integrity_result = database.query_one("PRAGMA integrity_check", as: {String})
    if integrity_result != "ok"
      Log.for("quickheadlines.storage").error { "Database integrity check failed: #{integrity_result}" }
      return DbHealthStatus::Corrupted
    end

    begin
      fk_result = database.query_one("PRAGMA foreign_key_check", as: Array(Array(Int64)))
      if fk_result && !fk_result.empty?
        Log.for("quickheadlines.storage").warn { "Database has #{fk_result.size} foreign key violations" }
      end
    rescue DB::Error
    end

    feed_count = database.query_one("SELECT COUNT(*) FROM feeds", as: {Int64})
    if feed_count == 0
      Log.for("quickheadlines.storage").warn { "Database has no feeds, needs repopulation" }
      return DbHealthStatus::NeedsRepopulation
    end

    Log.for("quickheadlines.storage").debug { "Database health check passed (#{feed_count} feeds)" }
    DbHealthStatus::Healthy
  end
rescue ex : Exception
  Log.for("quickheadlines.storage").error(exception: ex) { "Database health check failed" }
  DbHealthStatus::Corrupted
end

def repair_database(config : Config?, backup_path : String? = nil) : DbRepairResult
  db_path = get_cache_db_path(config)
  repair_time = Time.utc

  Log.for("quickheadlines.storage").warn { "Attempting to repair corrupted database..." }

  actual_backup_path = backup_path || "#{db_path}.corrupted.#{repair_time.to_s("%Y%m%d%H%M%S")}"

  unless File.exists?(actual_backup_path)
    begin
      File.rename(db_path, actual_backup_path) if File.exists?(db_path)
      Log.for("quickheadlines.storage").info { "Backed up corrupted database to: #{actual_backup_path}" }
    rescue ex : Exception
      Log.for("quickheadlines.storage").error(exception: ex) { "Failed to backup corrupted database" }
      return DbRepairResult.new(
        status: DbHealthStatus::Corrupted,
        backup_path: nil,
        repair_time: repair_time,
        feeds_to_restore: 0,
        items_to_restore: 0
      )
    end
  end

  begin
    init_db(config)
    Log.for("quickheadlines.storage").info { "Successfully repaired database (created new one)" }
    DbRepairResult.new(
      status: DbHealthStatus::Repaired,
      backup_path: actual_backup_path,
      repair_time: repair_time,
      feeds_to_restore: 0,
      items_to_restore: 0
    )
  rescue ex : Exception
    Log.for("quickheadlines.storage").error(exception: ex) { "Failed to create new database" }
    begin
      File.rename(actual_backup_path, db_path) if File.exists?(actual_backup_path)
      Log.for("quickheadlines.storage").info { "Restored backup database" }
    rescue ex : File::Error
      Log.for("quickheadlines.storage").error(exception: ex) { "Failed to restore backup database" }
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

def repopulate_database(config : Config?, cache : FeedCache?, restore_config : FeedRestoreConfig = FeedRestoreConfig.new) : Bool
  return false unless config

  Log.for("quickheadlines.storage").debug { "Repopulating database..." }

  timeframe_hours = restore_config.timeframe_hours

  all_feeds = [] of Feed
  all_feeds.concat(config.feeds)
  config.tabs.each do |tab|
    all_feeds.concat(tab.feeds)
  end

  feeds_to_restore = all_feeds.size

  Log.for("quickheadlines.storage").debug { "Would restore #{feeds_to_restore} feeds from past #{timeframe_hours} hours" }

  feeds_to_restore > 0
end

def init_db(config : Config?)
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path = get_cache_db_path(config)

  DB.open("sqlite3://#{db_path}") do |database|
    create_schema(database, db_path)
  end
end
