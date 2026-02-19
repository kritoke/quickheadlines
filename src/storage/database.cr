require "db"
require "sqlite3"
require "../config"
require "./cache_utils"

def create_schema(db : DB::Database, db_path : String)
  db.exec("PRAGMA journal_mode = WAL")
  db.exec("PRAGMA synchronous = NORMAL")
  db.exec("PRAGMA cache_size = -64000")

  db.exec <<-SQL
    CREATE TABLE IF NOT EXISTS feeds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      site_link TEXT,
      header_color TEXT,
      header_theme_colors TEXT,
      header_text_color TEXT,
      etag TEXT,
      last_modified TEXT,
      favicon TEXT,
      favicon_data TEXT,
      last_fetched TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    SQL

  begin
    db.exec("ALTER TABLE feeds ADD COLUMN favicon_data TEXT")
    STDERR.puts "[Cache] Added favicon_data column to existing database"
  rescue ex : SQLite3::Exception
  end

  begin
    db.exec("ALTER TABLE feeds ADD COLUMN header_text_color TEXT")
    STDERR.puts "[Cache] Added header_text_color column to existing database"
  rescue ex : SQLite3::Exception
  end

  begin
    db.exec("ALTER TABLE feeds ADD COLUMN header_theme_colors TEXT")
    STDERR.puts "[Cache] Added header_theme_colors column to existing database"
  rescue ex : SQLite3::Exception
  end

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

  begin
    db.exec("ALTER TABLE items ADD COLUMN minhash_signature BLOB")
    STDERR.puts "[Cache] Added minhash_signature column to existing database"
  rescue ex : SQLite3::Exception
  end

  begin
    db.exec("ALTER TABLE items ADD COLUMN cluster_id INTEGER REFERENCES items(id)")
    STDERR.puts "[Cache] Added cluster_id column to existing database"
  rescue ex : SQLite3::Exception
  end

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
    STDERR.puts "[Cache] Cleaned up #{cleanup_result.rows_affected} duplicate items from database"
  end

  db.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_items_unique_feed_link ON items(feed_id, link)")
end

def check_db_integrity(db_path : String) : Bool
  DB.open("sqlite3://#{db_path}") do |db|
    result = db.query_one("PRAGMA integrity_check", as: {String})
    if result == "ok"
      STDERR.puts "[#{Time.local}] Database integrity check passed"
      true
    else
      STDERR.puts "[ERROR] Database integrity check failed: #{result}"
      false
    end
  end
rescue ex : Exception
  STDERR.puts "[ERROR] Database integrity check failed: #{ex.message}"
  false
end

def check_db_health(db_path : String) : DbHealthStatus
  unless File.exists?(db_path)
    return DbHealthStatus::NeedsRepopulation
  end

  if File.size(db_path) < 100
    STDERR.puts "[WARN] Database file is too small (#{File.size(db_path)} bytes), may be empty"
    return DbHealthStatus::NeedsRepopulation
  end

  DB.open("sqlite3://#{db_path}") do |db|
    integrity_result = db.query_one("PRAGMA integrity_check", as: {String})
    if integrity_result != "ok"
      STDERR.puts "[ERROR] Database integrity check failed: #{integrity_result}"
      return DbHealthStatus::Corrupted
    end

    begin
      fk_result = db.query_one("PRAGMA foreign_key_check", as: Array(Array(Int64)))
      if fk_result && !fk_result.empty?
        STDERR.puts "[WARN] Database has #{fk_result.size} foreign key violations"
      end
    rescue ex
    end

    feed_count = db.query_one("SELECT COUNT(*) FROM feeds", as: {Int64})
    if feed_count == 0
      STDERR.puts "[WARN] Database has no feeds, needs repopulation"
      return DbHealthStatus::NeedsRepopulation
    end

    STDERR.puts "[#{Time.local}] Database health check passed (#{feed_count} feeds)"
    DbHealthStatus::Healthy
  end
rescue ex : Exception
  STDERR.puts "[ERROR] Database health check failed: #{ex.message}"
  DbHealthStatus::Corrupted
end

def repair_database(config : Config?, backup_path : String? = nil) : DbRepairResult
  db_path = get_cache_db_path(config)
  repair_time = Time.utc

  STDERR.puts "[#{repair_time}] Attempting to repair corrupted database..."

  actual_backup_path = backup_path || "#{db_path}.corrupted.#{repair_time.to_s("%Y%m%d%H%M%S")}"

  unless File.exists?(actual_backup_path)
    begin
      File.rename(db_path, actual_backup_path) if File.exists?(db_path)
      STDERR.puts "[#{repair_time}] Backed up corrupted database to: #{actual_backup_path}"
    rescue ex : Exception
      STDERR.puts "[ERROR] Failed to backup corrupted database: #{ex.message}"
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
    STDERR.puts "[#{repair_time}] Successfully repaired database (created new one)"
    DbRepairResult.new(
      status: DbHealthStatus::Repaired,
      backup_path: actual_backup_path,
      repair_time: repair_time,
      feeds_to_restore: 0,
      items_to_restore: 0
    )
  rescue ex : Exception
    STDERR.puts "[ERROR] Failed to create new database: #{ex.message}"
    begin
      File.rename(actual_backup_path, db_path) if File.exists?(actual_backup_path)
      STDERR.puts "[#{repair_time}] Restored backup database"
    rescue
      STDERR.puts "[ERROR] Failed to restore backup database"
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

  STDERR.puts "[#{Time.local}] Repopulating database..."

  timeframe_hours = restore_config.timeframe_hours

  all_feeds = [] of Feed
  all_feeds.concat(config.feeds)
  config.tabs.each do |tab|
    all_feeds.concat(tab.feeds)
  end

  feeds_to_restore = all_feeds.size
  items_to_restore = 0

  STDERR.puts "[#{Time.local}] Would restore #{feeds_to_restore} feeds from past #{timeframe_hours} hours"

  feeds_to_restore > 0
end

def init_db(config : Config?)
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path = get_cache_db_path(config)

  DB.open("sqlite3://#{db_path}") do |db|
    create_schema(db, db_path)
  end
end
