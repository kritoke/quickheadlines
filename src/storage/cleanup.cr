module CleanupRepository
  def cleanup_old_entries(retention_hours : Int32 = CACHE_RETENTION_HOURS, config_urls : Array(String)? = nil)
    @mutex.synchronize do
      log_db_size(@db_path, "before cleanup")

      cutoff = (Time.utc - retention_hours.hours).to_s("%Y-%m-%d %H:%M:%S")

      if config_urls && !config_urls.empty?
        url_list = config_urls.map { |url| "'#{url.gsub("'", "''")}'" }.join(",")
        result = @db.exec("DELETE FROM feeds WHERE last_fetched < ? AND url NOT IN (#{url_list})", cutoff)
      else
        result = @db.exec("DELETE FROM feeds WHERE last_fetched < ?", cutoff)
      end
      deleted_count = result.rows_affected
      STDERR.puts "[#{Time.local}] Cleaned up #{deleted_count} old feeds (older than #{retention_hours}h)" if deleted_count > 0

      log_db_size(@db_path, "after cleanup")
    end
  end

  def cleanup_old_articles(retention_days : Int32 = CACHE_RETENTION_DAYS)
    @mutex.synchronize do
      cutoff = (Time.utc - retention_days.days).to_s("%Y-%m-%d %H:%M:%S")

      result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
      deleted_count = result.rows_affected

      if deleted_count > 0
        STDERR.puts "[#{Time.local}] Cleaned up #{deleted_count} old articles (older than #{retention_days} days)"
      end

      result = @db.exec("DELETE FROM items WHERE feed_id NOT IN (SELECT id FROM feeds)")
      orphaned_count = result.rows_affected

      if orphaned_count > 0
        STDERR.puts "[#{Time.local}] Cleaned up #{orphaned_count} orphaned items"
      end
    end
  end

  def check_size_limit(max_size_mb : Int32 = 100)
    @mutex.synchronize do
      return unless @db_path && File.exists?(@db_path)

      current_size_mb = File.size(@db_path).to_f64 / (1024 * 1024)

      if current_size_mb > max_size_mb
        STDERR.puts "[#{Time.local}] Database size (#{current_size_mb.round(2)}MB) exceeds limit (#{max_size_mb}MB), running aggressive cleanup..."

        cutoff = (Time.utc - 3.days).to_s("%Y-%m-%d %H:%M:%S")
        result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
        deleted_count = result.rows_affected
        STDERR.puts "[#{Time.local}] Aggressive cleanup deleted #{deleted_count} old articles"

        if File.size(@db_path).to_f64 / (1024 * 1024) > max_size_mb
          cutoff = (Time.utc - 1.day).to_s("%Y-%m-%d %H:%M:%S")
          result = @db.exec("DELETE FROM items WHERE pub_date < ? AND cluster_id IS NULL", cutoff)
          deleted_count = result.rows_affected
          STDERR.puts "[#{Time.local}] Very aggressive cleanup deleted #{deleted_count} recent-old articles"
        end

        begin
          vacuum
          STDERR.puts "[#{Time.local}] Vacuumed database after size cleanup"
        rescue ex
          STDERR.puts "[#{Time.local}] Vacuum failed: #{ex.message}"
        end
      end
    end
  end

  def vacuum
    @mutex.synchronize do
      begin
        STDERR.puts "[#{Time.local}] Running VACUUM on database"
        @db.exec("VACUUM")
        STDERR.puts "[#{Time.local}] VACUUM completed"
      rescue ex
        STDERR.puts "[#{Time.local}] VACUUM failed: #{ex.message}"
      end
    end
  end

  def normalize_pub_dates
    @mutex.synchronize do
      STDERR.puts "[#{Time.local}] Normalizing pub_date values..."

      rows = [] of {Int64, String?}
      @db.query("SELECT id, pub_date FROM items WHERE pub_date IS NOT NULL") do |r|
        r.each do
          rows << {r.read(Int64), r.read(String?)}
        end
      end

      updated = 0
      rows.each do |id, raw|
        next if raw.nil?
        str = raw.as(String)

        if str =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/
          next
        end

        parsed = nil.as(Time?)

        begin
          begin
            parsed = Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC)
          rescue
          end

          if !parsed
            begin
              parsed = Time.parse(str, "%Y-%m-%dT%H:%M:%S%z", Time::Location::UTC)
            rescue
            end
          end

          if !parsed
            begin
              parsed = Time.parse(str, "%Y-%m-%dT%H:%M:%SZ", Time::Location::UTC)
            rescue
            end
          end

          if !parsed
            begin
              parsed = Time.parse(str, "%a, %d %b %Y %H:%M:%S %z", Time::Location::UTC)
            rescue
            end
          end
        rescue
          parsed = nil
        end

        if parsed
          formatted = parsed.to_s("%Y-%m-%d %H:%M:%S")
          if formatted != str
            @db.exec("UPDATE items SET pub_date = ? WHERE id = ?", formatted, id)
            updated += 1
          end
        end
      end

      STDERR.puts "[#{Time.local}] Normalized #{updated} pub_date rows"
    end
  rescue ex
    STDERR.puts "[#{Time.local}] Error normalizing pub_date: #{ex.message}"
  end
end
