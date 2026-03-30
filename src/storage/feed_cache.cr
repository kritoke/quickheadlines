require "db"
require "sqlite3"
require "mutex"
require "time"
require "openssl"
require "uri"
require "../config"
require "../constants"
require "../models"
require "../result"
require "../errors"
require "../favicon_storage"
require "../color_extractor"
require "../health_monitor"
require "../services/database_service"
require "./cache_utils"
require "./database"
require "./clustering_repo"
require "./header_colors"
require "./cleanup"
require "../repositories/feed_repository"

class FeedCache
  include ClusteringRepository
  include HeaderColorsRepository
  include CleanupRepository

  @mutex : Mutex
  @db : DB::Database
  @db_path : String
  @feed_repository : Quickheadlines::Repositories::FeedRepository?

  def initialize(config : Config?, db : DB::Database? = nil)
    @mutex = Mutex.new
    cache_dir = get_cache_dir(config)
    ensure_cache_dir(cache_dir)

    db_path = get_cache_db_path(config).as(String)
    @db_path = db_path

    # Use provided db, otherwise try to use DatabaseService, otherwise create new connection
    if db
      @db = db
    else
      @db = begin
        DatabaseService.instance.db
      rescue
        DB.open("sqlite3://#{@db_path}")
      end
    end
    create_schema(@db, @db_path)
    STDERR.puts "[#{Time.local}] Database initialized: #{@db_path}"

    log_db_size(@db_path, "on startup")
  end

  private def feed_repository : Quickheadlines::Repositories::FeedRepository
    @feed_repository ||= Quickheadlines::Repositories::FeedRepository.new(@db)
  end

  getter :db_path

  def add(feed_data : FeedData)
    feed_repository.upsert_with_items(feed_data)
  end

  def get(url : String) : FeedData?
    feed_repository.find_with_items(url)
  end

  def get_result(url : String) : FeedDataResult
    feed_repository.find_with_items_result(url)
  end

  def get_fetched_time(url : String) : Time?
    feed_repository.find_last_fetched_time(url)
  end

  def get_fetched_time_result(url : String) : TimeResult
    feed_repository.find_last_fetched_time_result(url)
  end

  def get_slice(url : String, limit : Int32, offset : Int32) : FeedData?
    feed_repository.find_with_items_slice(url, limit, offset)
  end

  def get_slice_result(url : String, limit : Int32, offset : Int32) : FeedDataResult
    feed_repository.find_with_items_slice_result(url, limit, offset)
  end

  def item_count(url : String) : Int32
    feed_repository.count_items(url)
  end

  def size : Int32
    feed_repository.count_all
  end

  def entries : Hash(String, FeedData)
    @mutex.synchronize do
      urls = {} of String => FeedData
      feed_repository.find_all_urls.each do |url|
        if feed = feed_repository.find_with_items(url)
          urls[url] = feed
        end
      end
      urls
    end
  end

  def sync_favicon_paths
    feeds_data = [] of {Int64, String, String?, String?, String?, String?, String}
    local_backfills = [] of {Int64, String, String}
    google_backfills = [] of {Int64, String, String}
    missing_backfills = [] of {Int64, String, String}

    @db.query("SELECT id, url, favicon, favicon_data, header_color, header_theme_colors, site_link FROM feeds") do |rows|
      rows.each do
        feed_id = rows.read(Int64)
        url = rows.read(String)
        favicon = rows.read(String?)
        favicon_data = rows.read(String?)
        header_color = rows.read(String?)
        header_theme_colors = rows.read(String?)
        site_link = rows.read(String)
        feeds_data << {feed_id, url, favicon, favicon_data, header_color, header_theme_colors, site_link}
      end
    end

    feeds_data.each do |feed_id, url, favicon, favicon_data, _, header_theme_colors, site_link|
      clear_external_favicon = false
      sync_favicon_data = nil
      clear_favicon = false
      update_favicon = nil
      update_favicon_data = nil

      if favicon_data && favicon_data.starts_with?("http")
        clear_external_favicon = true
        favicon_data = nil
      end

      if favicon && favicon_data.nil? && favicon.starts_with?("/favicons/")
        sync_favicon_data = favicon
      end

      if favicon && favicon.starts_with?("http") && !favicon.includes?("google.com/s2/favicons")
        hash = OpenSSL::Digest.new("SHA256").update(favicon).final.hexstring
        possible_extensions = ["png", "jpg", "jpeg", "ico", "svg", "webp"]

        found_local = false
        possible_extensions.each do |ext|
          filename = "#{hash[0...16]}.#{ext}"
          filepath = File.join(FaviconStorage.favicon_dir, filename)
          if File.exists?(filepath)
            local_path = "/favicons/#{filename}"
            found_local = true
            update_favicon = local_path
            update_favicon_data = local_path
            favicon = local_path
            break
          end
        end

        unless found_local
          clear_favicon = true
          favicon = nil
        end
      end

      if header_theme_colors.nil? && favicon && favicon.starts_with?("/favicons/")
        local_backfills << {feed_id, url, favicon}
      end

      if header_theme_colors.nil? && favicon && favicon.starts_with?("http") && favicon.includes?("google.com/s2/favicons")
        google_backfills << {feed_id, url, favicon}
      end

      if header_theme_colors.nil? && favicon.nil? && site_link && !site_link.empty?
        missing_backfills << {feed_id, url, site_link}
      end

      @mutex.synchronize do
        if clear_external_favicon
          @db.exec("UPDATE feeds SET favicon_data = NULL WHERE id = ?", feed_id)
          STDERR.puts "[Cache] Cleared external URL from favicon_data for #{url}"
        end

        if sync_favicon_data
          @db.exec("UPDATE feeds SET favicon_data = ? WHERE id = ?", sync_favicon_data, feed_id)
          STDERR.puts "[Cache] Synced favicon_data for #{url}: #{sync_favicon_data}"
        end

        if update_favicon && update_favicon_data
          @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", update_favicon, update_favicon_data, feed_id)
          STDERR.puts "[Cache] Synced favicon for #{url}: #{favicon}"
        end

        if clear_favicon
          @db.exec("UPDATE feeds SET favicon = NULL, favicon_data = NULL WHERE id = ?", feed_id)
          STDERR.puts "[Cache] Cleared missing favicon for #{url}"
        end
      end
    end

    STDERR.puts "[Cache] Backfill summary: local=#{local_backfills.size}, google=#{google_backfills.size}, missing=#{missing_backfills.size}"

    local_backfills.each { |args| backfill_header_colors(*args) }

    google_backfills.each do |feed_id, url, google_url|
      STDERR.puts "[Cache] Processing Google favicon backfill for #{url}: #{google_url}"
      url_to_fetch = google_url
      if google_url.includes?("domain=#")
        parsed = URI.parse(url)
        host = parsed.host
        if host && host.includes?(".")
          url_to_fetch = "https://www.google.com/s2/favicons?domain=#{host}&sz=256"
          STDERR.puts "[Cache] Fixed broken domain=# in Google URL: #{url_to_fetch}"
        end
      end
      local_path = FaviconStorage.fetch_and_save(url_to_fetch)
      STDERR.puts "[Cache] fetch_and_save returned: #{local_path.inspect}"
      if local_path
        @mutex.synchronize do
          @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", local_path, local_path, feed_id)
        end
        STDERR.puts "[Cache] Downloaded Google favicon for #{url}: #{local_path}"
        backfill_header_colors(feed_id, url, local_path)
      end
    end

    missing_backfills.each do |feed_id, url, site_link|
      begin
        uri = URI.parse(site_link)
        host = uri.host
        if host && !host.includes?("#") && host.includes?(".")
          google_url = "https://www.google.com/s2/favicons?domain=#{host}&sz=256"
          local_path = FaviconStorage.fetch_and_save(google_url)
          if local_path
            @mutex.synchronize do
              @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", local_path, local_path, feed_id)
            end
            STDERR.puts "[Cache] Backfilled missing favicon for #{url}: #{local_path}"
            backfill_header_colors(feed_id, url, local_path)
          end
        end
      rescue ex
        STDERR.puts "[Cache] Backfill missing favicon failed for #{url}: #{ex.message}"
      end
    end
  end

  private def backfill_header_colors(feed_id : Int64, feed_url : String, favicon_path : String)
    extracted = ColorExtractor.theme_aware_extract_from_favicon(favicon_path, feed_url, nil)
    return unless extracted

    bg = extracted["bg"]?.try(&.to_s)
    text_val = extracted["text"]?
    return unless bg || text_val

    theme_json = extracted.to_json
    text_light = nil
    text_dark = nil

    if text_val.is_a?(Hash)
      text_light = text_val.as(Hash)["light"]?.try(&.to_s)
      text_dark = text_val.as(Hash)["dark"]?.try(&.to_s)
    elsif text_val.is_a?(String)
      text_light = text_val.to_s
      text_dark = text_val.to_s
    end

    legacy_text = text_light || text_dark

    @db.exec("UPDATE feeds SET header_color = ?, header_text_color = ?, header_theme_colors = ? WHERE id = ?",
      bg, legacy_text, theme_json, feed_id)
    STDERR.puts "[Cache] Backfilled header colors for #{feed_url}: bg=#{bg}, text=#{legacy_text}"
  rescue ex
    STDERR.puts "[Cache] Backfill header colors failed for #{feed_url}: #{ex.message}"
  end

  def ensure_indexes
    @mutex.synchronize do
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_feed_id ON items(feed_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_pub_date ON items(pub_date DESC)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_last_fetched ON feeds(last_fetched DESC)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds(url)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_cluster ON items(cluster_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_lsh_band_search ON lsh_bands(band_index, band_hash)")
      # Composite indexes for timeline query optimization
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_timeline ON items(pub_date DESC, id DESC, cluster_id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_cluster_rep ON items(cluster_id, id)")
      @db.exec("CREATE INDEX IF NOT EXISTS idx_items_feed_timeline ON items(feed_id, pub_date DESC, id DESC)")
    end
  rescue ex
    STDERR.puts "[#{Time.local}] Warning: ensure_indexes failed: #{ex.message}"
  end

  def clear_all
    @mutex.synchronize do
      @db.exec("DELETE FROM items")
      @db.exec("DELETE FROM feeds")
      @db.exec("DELETE FROM lsh_bands")
      STDERR.puts "[#{Time.local}] Cleared all cached data"
    end
  end

  def db : DB::Database
    @db
  end

  def close
    @mutex.synchronize do
      @db.close
    end
  end
end

def load_feed_cache(config : Config?) : FeedCache
  cache_dir = get_cache_dir(config)
  ensure_cache_dir(cache_dir)
  db_path : String = get_cache_db_path(config)

  init_db(config) unless File.exists?(db_path)

  health_status = DbHealthStatus::Healthy
  if File.exists?(db_path)
    health_status = check_db_health(db_path)

    case health_status
    when DbHealthStatus::Corrupted
      STDERR.puts "[ERROR] Database corruption detected, attempting repair..."
      repair_result = repair_database(config)

      if repair_result.status == DbHealthStatus::Repaired
        STDERR.puts "[#{Time.local}] Database was previously repaired"
      end
    end
  end

  cache = FeedCache.new(config)

  cache.ensure_indexes

  cache.sync_favicon_paths

  if health_status == DbHealthStatus::Healthy
    cache.cleanup_old_articles(Constants::CACHE_RETENTION_DAYS)
  end

  retention_hours = config.try(&.cache_retention_hours) || Constants::CACHE_RETENTION_HOURS

  config_urls = config.try do |conf|
    urls = conf.feeds.map(&.url)
    conf.tabs.each do |tab|
      urls.concat(tab.feeds.map(&.url))
    end
    urls
  end

  cache.cleanup_old_entries(retention_hours, config_urls)

  cache.check_size_limit(Constants::DB_SIZE_HARD_LIMIT)

  db_size = get_db_size(cache.db_path)
  if db_size > 10 * 1024 * 1024
    cache.vacuum
  end

  cache
end

def save_feed_cache(cache : FeedCache, retention_hours : Int32 = Constants::CACHE_RETENTION_HOURS, max_cache_size_mb : Int32 = 100)
  cache.check_size_limit(max_cache_size_mb)

  if rand(100) < 5
    begin
      cache.vacuum
    rescue ex
      STDERR.puts "[#{Time.local}] Warning: vacuum failed: #{ex.message}"
    end
  end

  if rand(100) < 10
    cache.cleanup_old_entries(retention_hours)
  end

  if rand(100) < 10
    cache.cleanup_old_articles(Constants::CACHE_RETENTION_DAYS)
  end

  cache.sync_favicon_paths
end

def cache_fresh?(last_fetched : Time, max_age_minutes : Int32 = 10) : Bool
  (Time.utc - last_fetched).total_minutes < max_age_minutes
end
