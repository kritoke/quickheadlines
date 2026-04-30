require "db"
require "sqlite3"
require "mutex"
require "time"
require "json"
require "log"
require "./store_interface"
require "./constants"
require "./models/article_content"

module Azurite
  class Store
    include StoreInterface
    @db : DB::Database
    @db_path : String
    @retention_days : Int32
    @max_size_mb : Int32
    @warning_size_mb : Int32
    @hard_limit_mb : Int32
    @max_content_bytes : Int32
    @mutex : Mutex
    @auto_cleanup_enabled : Bool
    @auto_cleanup_interval : Time::Span
    @cleanup_channel : ::Channel(Nil)

    def initialize(
      @db_path : String,
      @retention_days : Int32,
      @max_size_mb : Int32,
      @warning_size_mb : Int32,
      @hard_limit_mb : Int32,
      @max_content_bytes : Int32,
    )
      validate_db_path
      @mutex = Mutex.new
      @auto_cleanup_enabled = false
      @auto_cleanup_interval = 1.hour
      @cleanup_channel = ::Channel(Nil).new
      @db = DB.open("sqlite3:#{@db_path}")
      init_schema
      Log.for("azurite").info { "AzuriteStore initialized: #{@db_path}" }
    end

    def start_auto_cleanup(interval : Time::Span = 1.hour) : Nil
      @auto_cleanup_enabled = true
      @auto_cleanup_interval = interval
      spawn_auto_cleanup
      Log.for("azurite").info { "Auto cleanup started with interval: #{interval}" }
    end

    def stop_auto_cleanup : Nil
      @auto_cleanup_enabled = false
      @cleanup_channel.send(nil)
      Log.for("azurite").info { "Auto cleanup stopped" }
    end

    private def spawn_auto_cleanup
      spawn do
        loop do
          select
          when @cleanup_channel.receive
            break
          when timeout @auto_cleanup_interval
            if @auto_cleanup_enabled
              enforce_size_limits
            end
          end
        end
      end
    end

    private def validate_db_path
      dir = File.dirname(@db_path)
      if dir != "." && !Dir.exists?(dir)
        raise ArgumentError.new("Database directory does not exist: #{dir}")
      end
      if File.exists?(@db_path) && !File.writable?(@db_path)
        raise ArgumentError.new("Database file is not writable: #{@db_path}")
      end
    end

    private def init_schema
      @db.exec <<-SQL # ameba:disable Style/HeredocIndent
        CREATE TABLE IF NOT EXISTS article_content (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_link TEXT UNIQUE NOT NULL,
          feed_url TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          content_type TEXT DEFAULT 'html',
          fetched_at TEXT NOT NULL,
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
        )
      SQL

      @db.exec("CREATE INDEX IF NOT EXISTS idx_content_link ON article_content(item_link)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_content_feed ON article_content(feed_url)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_content_created ON article_content(created_at)")
    end

    def store(item_link : String, feed_url : String, title : String, content : String, content_type : String = Azurite::Constants::DEFAULT_CONTENT_TYPE) : Bool
      @mutex.synchronize do
        truncated_content = truncate_content(content)
        fetched_at = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")

        @db.exec(
          "INSERT INTO article_content (item_link, feed_url, title, content, content_type, fetched_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(item_link) DO UPDATE SET feed_url = excluded.feed_url, title = excluded.title, content = excluded.content, content_type = excluded.content_type, fetched_at = excluded.fetched_at",
          item_link, feed_url, title, truncated_content, content_type, fetched_at
        )
        true
      rescue ex
        Log.for("azurite").error(exception: ex) { "Failed to store content for #{item_link}" }
        false
      end
    end

    def get_content(item_link : String) : String?
      @mutex.synchronize do
        @db.query_one?(
          "SELECT content FROM article_content WHERE item_link = ? LIMIT 1",
          item_link,
          as: String
        )
      end
    rescue ex
      Log.for("azurite").error(exception: ex) { "Failed to get content for #{item_link}" }
      nil
    end

    def get_article(item_link : String) : ArticleContent?
      @mutex.synchronize do
        @db.query_one?(
          "SELECT id, item_link, feed_url, title, content, content_type, fetched_at, created_at FROM article_content WHERE item_link = ? LIMIT 1",
          item_link
        ) do |row|
          ArticleContent.from_row(row)
        end
      end
    rescue ex
      Log.for("azurite").error(exception: ex) { "Failed to get article for #{item_link}" }
      nil
    end

    def articles_for_feed(feed_url : String) : Array(ArticleContent)
      @mutex.synchronize do
        articles = [] of ArticleContent
        @db.query(
          "SELECT id, item_link, feed_url, title, content, content_type, fetched_at, created_at FROM article_content WHERE feed_url = ? ORDER BY created_at DESC",
          feed_url
        ) do |row|
          row.each do
            articles << ArticleContent.from_row(row)
          end
        end
        articles
      end
    rescue ex
      Log.for("azurite").error(exception: ex) { "Failed to get articles for feed #{feed_url}" }
      [] of ArticleContent
    end

    def cleanup_old_entries(retention_days : Int32? = nil) : Int32
      days = retention_days || @retention_days
      @mutex.synchronize do
        cutoff = (Time.utc - days.days).to_s("%Y-%m-%dT%H:%M:%SZ")
        result = @db.exec("DELETE FROM article_content WHERE created_at < ?", cutoff)
        deleted = result.rows_affected.to_i32
        if deleted > 0
          Log.for("azurite").info { "Cleaned up #{deleted} old articles (older than #{days} days)" }
        end
        deleted
      end
    rescue ex
      Log.for("azurite").error(exception: ex) { "Failed to cleanup old entries" }
      0
    end

    def db_size_mb : Float64
      return 0.0 unless File.exists?(@db_path)
      File.size(@db_path).to_f64 / (1024 * 1024)
    end

    def enforce_size_limits : Nil
      current_size_mb = db_size_mb

      if current_size_mb > @hard_limit_mb
        Log.for("azurite").warn { "Content DB size (#{current_size_mb.round(2)}MB) exceeds hard limit (#{@hard_limit_mb}MB), running aggressive cleanup..." }
        aggressive_cleanup
      elsif current_size_mb > @max_size_mb
        Log.for("azurite").warn { "Content DB size (#{current_size_mb.round(2)}MB) exceeds soft limit (#{@max_size_mb}MB)" }
        cleanup_old_entries({(@retention_days / 2).to_i32, 1}.max)
      elsif current_size_mb > @warning_size_mb
        Log.for("azurite").info { "Content DB size: #{current_size_mb.round(2)}MB (warning threshold: #{@warning_size_mb}MB)" }
      end
    end

    private def aggressive_cleanup
      cleanup_old_entries({(@retention_days / 3).to_i32, 1}.max)
      vacuum
    end

    private def vacuum
      @db.exec("VACUUM")
      Log.for("azurite").info { "Vacuumed content database" }
    end

    private def truncate_content(content : String) : String
      return content if content.bytesize <= @max_content_bytes
      sliced = content.byte_slice(0, @max_content_bytes)
      return sliced if sliced.valid_encoding?
      i = @max_content_bytes
      while !content.byte_slice(0, i).valid_encoding? && i > 0
        i -= 1
      end
      content.byte_slice(0, i)
    end

    def close : Nil
      if @auto_cleanup_enabled
        stop_auto_cleanup
      end
      @db.close
    end
  end
end
