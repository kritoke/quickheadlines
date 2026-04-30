require "../constants"
require "../repositories/repository_base"

module QuickHeadlines::Storage
  class CleanupStore
    # Maximum WAL size before forcing a checkpoint truncate (500MB)
    MAX_WAL_SIZE_BEFORE_TRUNCATE = 500 * 1024 * 1024

    def initialize(@db : DB::Database, @mutex : Mutex, @db_path : String)
    end

    # Called at startup and periodically to ensure WAL doesn't grow unbounded
    def ensure_wal_checkpoint
      @mutex.synchronize { perform_wal_checkpoint(truncate: false) }
    end

    def cleanup_old_entries(retention_hours : Int32 = QuickHeadlines::Constants::CACHE_RETENTION_HOURS, config_urls : Array(String)? = nil)
      @mutex.synchronize do
        log_db_size(@db_path, "before cleanup")

        cutoff = (Time.utc - retention_hours.hours).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)

        if config_urls && !config_urls.empty?
          placeholders = QuickHeadlines::Repositories::RepositoryBase.placeholders(config_urls.size)
          args = [cutoff] + config_urls
          result = @db.exec("DELETE FROM feeds WHERE last_fetched < ? AND url NOT IN (#{placeholders})", args: args)
        else
          result = @db.exec("DELETE FROM feeds WHERE last_fetched < ?", cutoff)
        end
        deleted_count = result.rows_affected
        Log.for("quickheadlines.storage").debug { "Cleaned up #{deleted_count} old feeds (older than #{retention_hours}h)" } if deleted_count > 0

        log_db_size(@db_path, "after cleanup")
      end
    end

    def remove_stale_feeds(config_urls : Array(String))
      @mutex.synchronize do
        if config_urls.empty?
          Log.for("quickheadlines.storage").warn { "No config URLs provided, skipping stale feed cleanup" }
          return
        end

        placeholders = QuickHeadlines::Repositories::RepositoryBase.placeholders(config_urls.size)
        result = @db.exec("DELETE FROM feeds WHERE url NOT IN (#{placeholders})", args: config_urls)
        deleted_count = result.rows_affected
        if deleted_count > 0
          Log.for("quickheadlines.storage").info { "Removed #{deleted_count} stale feeds not in config" }
        end
      end
    end

    def cleanup_old_articles(retention_days : Int32 = QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
      @mutex.synchronize do
        cutoff = (Time.utc - retention_days.days).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)

        @db.transaction do
          result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
          deleted_count = result.rows_affected

          if deleted_count > 0
            Log.for("quickheadlines.storage").debug { "Cleaned up #{deleted_count} old articles (older than #{retention_days} days)" }
          end

          result = @db.exec("DELETE FROM items WHERE feed_id NOT IN (SELECT id FROM feeds)")
          orphaned_count = result.rows_affected

          if orphaned_count > 0
            Log.for("quickheadlines.storage").debug { "Cleaned up #{orphaned_count} orphaned items" }
          end

          delete_orphaned_lsh_bands
        end
      end
    end

    def check_size_limit(max_size_mb : Int32 = 100)
      @mutex.synchronize do
        return unless @db_path && File.exists?(@db_path)

        current_size_mb = File.size(@db_path).to_f64 / (1024 * 1024)

        if current_size_mb > max_size_mb
          Log.for("quickheadlines.storage").warn { "Database size (#{current_size_mb.round(2)}MB) exceeds limit (#{max_size_mb}MB), running aggressive cleanup..." }

          cutoff = (Time.utc - QuickHeadlines::Constants::AGGRESSIVE_CLEANUP_DAYS.days).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
          result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
          deleted_count = result.rows_affected
          Log.for("quickheadlines.storage").info { "Aggressive cleanup deleted #{deleted_count} old articles" }

          if File.size(@db_path).to_f64 / (1024 * 1024) > max_size_mb
            cutoff = (Time.utc - QuickHeadlines::Constants::VERY_AGGRESSIVE_CLEANUP_DAYS.days).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
            result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
            deleted_count = result.rows_affected
            Log.for("quickheadlines.storage").info { "Very aggressive cleanup deleted #{deleted_count} recent-old articles" }
          end

          delete_orphaned_lsh_bands

          begin
            run_vacuum
            Log.for("quickheadlines.storage").info { "Vacuumed database after size cleanup" }
          rescue ex : Exception
            if ex.message.try(&.includes?("database is locked")) || ex.message.try(&.includes?("database locked"))
              Log.for("quickheadlines.storage").warn { "VACUUM skipped - database is locked (likely refresh in progress)" }
            else
              Log.for("quickheadlines.storage").error(exception: ex) { "Vacuum failed" }
            end
          end
        end
      end
    end

    def vacuum
      @mutex.synchronize do
        run_wal_checkpoint
        run_vacuum
      end
    end

    private def perform_wal_checkpoint(truncate : Bool)
      wal_size = wal_file_size
      if truncate || wal_size > MAX_WAL_SIZE_BEFORE_TRUNCATE
        Log.for("quickheadlines.storage").warn { "WAL file size (#{wal_size / (1024 * 1024)}MB) exceeds limit or truncate requested, checkpointing with TRUNCATE" }
        @db.exec("PRAGMA wal_checkpoint(TRUNCATE)")
      elsif wal_size > 0
        @db.exec("PRAGMA wal_checkpoint(PASSIVE)")
        Log.for("quickheadlines.storage").debug { "WAL checkpoint performed, size: #{wal_size / (1024 * 1024)}MB" }
      end
    rescue ex : Exception
      Log.for("quickheadlines.storage").warn { "WAL checkpoint failed: #{ex.message}" }
    end

    private def run_wal_checkpoint
      perform_wal_checkpoint(truncate: false)
    end

    private def actual_wal_file_size : Int64
      wal_path = "#{@db_path}-wal"
      if File.exists?(wal_path)
        File.size(wal_path)
      else
        0_i64
      end
    rescue ex
      0_i64
    end

    private def wal_file_size : Int64
      wal_path = "#{@db_path}-wal"
      File.exists?(wal_path) ? File.size(wal_path) : 0_i64
    rescue ex
      Log.for("quickheadlines.storage").warn { "Failed to check WAL file size: #{ex.message}" }
      0_i64
    end

    private def run_vacuum
      Log.for("quickheadlines.storage").debug { "Running VACUUM on database" }
      @db.exec("VACUUM")
      Log.for("quickheadlines.storage").debug { "VACUUM completed" }
    end

    private def delete_orphaned_lsh_bands
      result = @db.exec("DELETE FROM lsh_bands WHERE item_id NOT IN (SELECT id FROM items)")
      deleted_count = result.rows_affected
      if deleted_count > 0
        Log.for("quickheadlines.storage").debug { "Cleaned up #{deleted_count} orphaned LSH band entries" }
      end
    end

    private def try_parse_date_format(str : String, format : String) : Time?
      Time.parse(str, format, Time::Location::UTC)
    rescue Time::Format::Error
      nil
    end

    private def parse_date_with_formats(str : String) : Time?
      formats = [
        QuickHeadlines::Constants::DB_TIME_FORMAT,
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%SZ",
        "%a, %d %b %Y %H:%M:%S %z",
      ]

      formats.each do |fmt|
        if parsed = try_parse_date_format(str, fmt)
          return parsed
        end
      end
      nil
    end

    def normalize_pub_dates
      @mutex.synchronize do
        batch_size = QuickHeadlines::Constants::NORMALIZE_BATCH_SIZE
        total_updated = 0

        loop do
          rows = [] of {Int64, String?}
          @db.query("SELECT id, pub_date FROM items WHERE pub_date IS NOT NULL AND date_normalized = 0 LIMIT ?", batch_size) do |result_set|
            result_set.each do
              rows << {result_set.read(Int64), result_set.read(String?)}
            end
          end

          break if rows.empty?

          updated = 0
          rows.each do |id, raw|
            next if raw.nil?
            str = raw.as(String)

            is_normalized = str =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/

            if is_normalized
              @db.exec("UPDATE items SET date_normalized = 1 WHERE id = ?", id)
            elsif parsed = parse_date_with_formats(str)
              formatted = parsed.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
              if formatted != str
                @db.exec("UPDATE items SET pub_date = ?, date_normalized = 1 WHERE id = ?", formatted, id)
                updated += 1
              else
                @db.exec("UPDATE items SET date_normalized = 1 WHERE id = ?", id)
              end
            else
              @db.exec("UPDATE items SET date_normalized = 1 WHERE id = ?", id)
            end
          end

          total_updated += updated
          Log.for("quickheadlines.storage").debug { "Normalized batch: #{updated} rows updated" }
          break if rows.size < batch_size
        end

        Log.for("quickheadlines.storage").debug { "Normalized #{total_updated} pub_date rows total" }
      end
    rescue ex
      Log.for("quickheadlines.storage").error(exception: ex) { "Error normalizing pub_date" }
    end
  end
end
