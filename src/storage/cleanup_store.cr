require "../constants"

module QuickHeadlines::Storage
  class CleanupStore
    def initialize(@db : DB::Database, @mutex : Mutex, @db_path : String)
    end

    def cleanup_old_entries(retention_hours : Int32 = QuickHeadlines::Constants::CACHE_RETENTION_HOURS, config_urls : Array(String)? = nil)
      @mutex.synchronize do
        log_db_size(@db_path, "before cleanup")

        cutoff = (Time.utc - retention_hours.hours).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)

        if config_urls && !config_urls.empty?
          placeholders = Array.new(config_urls.size, "?").join(",")
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

        placeholders = Array.new(config_urls.size, "?").join(",")
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
      end
    end

    def check_size_limit(max_size_mb : Int32 = 100)
      @mutex.synchronize do
        return unless @db_path && File.exists?(@db_path)

        current_size_mb = File.size(@db_path).to_f64 / (1024 * 1024)

        if current_size_mb > max_size_mb
          Log.for("quickheadlines.storage").warn { "Database size (#{current_size_mb.round(2)}MB) exceeds limit (#{max_size_mb}MB), running aggressive cleanup..." }

          cutoff = (Time.utc - 3.days).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
          result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
          deleted_count = result.rows_affected
          Log.for("quickheadlines.storage").info { "Aggressive cleanup deleted #{deleted_count} old articles" }

          if File.size(@db_path).to_f64 / (1024 * 1024) > max_size_mb
            cutoff = (Time.utc - 1.day).to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
            result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
            deleted_count = result.rows_affected
            Log.for("quickheadlines.storage").info { "Very aggressive cleanup deleted #{deleted_count} recent-old articles" }
          end

          begin
            vacuum
            Log.for("quickheadlines.storage").info { "Vacuumed database after size cleanup" }
          rescue ex
            Log.for("quickheadlines.storage").error(exception: ex) { "Vacuum failed" }
          end
        end
      end
    end

    def vacuum
      @mutex.synchronize do
        begin
          Log.for("quickheadlines.storage").debug { "Running VACUUM on database" }
          @db.exec("VACUUM")
          Log.for("quickheadlines.storage").debug { "VACUUM completed" }
        rescue ex
          Log.for("quickheadlines.storage").error(exception: ex) { "VACUUM failed" }
        end
      end
    end

    private def try_parse_date_format(str : String, format : String) : Time?
      Time.parse(str, format, Time::Location::UTC)
    rescue ex : Time::Format::Error
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
        Log.for("quickheadlines.storage").debug { "Normalizing pub_date values..." }

        rows = [] of {Int64, String?}
        @db.query("SELECT id, pub_date FROM items WHERE pub_date IS NOT NULL") do |result_set|
          result_set.each do
            rows << {result_set.read(Int64), result_set.read(String?)}
          end
        end

        updated = 0
        rows.each do |id, raw|
          next if raw.nil?
          str = raw.as(String)

          next if str =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/

          if parsed = parse_date_with_formats(str)
            formatted = parsed.to_s(QuickHeadlines::Constants::DB_TIME_FORMAT)
            if formatted != str
              @db.exec("UPDATE items SET pub_date = ? WHERE id = ?", formatted, id)
              updated += 1
            end
          end
        end

        Log.for("quickheadlines.storage").debug { "Normalized #{updated} pub_date rows" }
      end
    rescue ex
      Log.for("quickheadlines.storage").error(exception: ex) { "Error normalizing pub_date" }
    end
  end
end
