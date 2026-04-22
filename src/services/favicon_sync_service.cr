require "db"
require "sqlite3"
require "mutex"
require "uri"
require "../config"
require "../models"
require "../favicon_storage"
require "../color_extractor"

class FaviconSyncService
  @db : DB::Database
  @mutex : Mutex

  def initialize(@db : DB::Database)
    @mutex = Mutex.new
  end

  def sync_favicon_paths : Nil
    feeds_data = load_feeds_data
    local_backfills = [] of {Int64, String, String}
    google_backfills = [] of {Int64, String, String}
    missing_backfills = [] of {Int64, String, String}

    feeds_data.each do |feed_id, url, favicon, favicon_data, header_color, header_theme_colors, site_link|
      clear_external, sync_data, update_fav, update_fav_data, clear_fav =
        process_feed_favicon(feed_id, url, favicon, favicon_data, header_color, header_theme_colors, site_link)

      @mutex.synchronize { apply_favicon_updates(feed_id, url, clear_external, sync_data, update_fav, update_fav_data, clear_fav) }

      categorize_backfill(feed_id, url, favicon, header_theme_colors, site_link, local_backfills, google_backfills, missing_backfills)
    end

    Log.for("quickheadlines.cache").info { "Backfill summary: local=#{local_backfills.size}, google=#{google_backfills.size}, missing=#{missing_backfills.size}" }

    local_backfills.each { |args| backfill_header_colors(*args) }
    process_google_backfills(google_backfills)
    process_missing_backfills(missing_backfills)
  end

  private def load_feeds_data : Array({Int64, String, String?, String?, String?, String?, String})
    feeds_data = [] of {Int64, String, String?, String?, String?, String?, String}
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
    feeds_data
  end

  private def process_feed_favicon(feed_id, url, favicon, favicon_data, _header_color, header_theme_colors, site_link)
    clear_external = false
    sync_favicon_data = nil
    clear_favicon = false
    update_favicon = nil
    update_favicon_data = nil

    if favicon_data && favicon_data.starts_with?("http")
      clear_external = true
      favicon_data = nil
    end

    if favicon && favicon_data.nil? && favicon.starts_with?("/favicons/")
      sync_favicon_data = favicon
    end

    if favicon && favicon.starts_with?("http") && !favicon.includes?("google.com/s2/favicons")
      found_local, local_path = find_local_favicon(favicon)
      if found_local
        update_favicon = local_path
        update_favicon_data = local_path
      else
        clear_favicon = true
      end
    end

    {clear_external, sync_favicon_data, update_favicon, update_favicon_data, clear_favicon}
  end

  private def find_local_favicon(favicon : String) : Tuple(Bool, String?)
    hash = FaviconStorage.favicon_hash_for_url_full(favicon)
    FaviconStorage::POSSIBLE_EXTENSIONS.each do |ext|
      filename = "#{hash[0...QuickHeadlines::Constants::FAVICON_HASH_PREFIX_LENGTH]}.#{ext}"
      filepath = File.join(FaviconStorage.favicon_dir, filename)
      if File.exists?(filepath)
        return {true, "/favicons/#{filename}"}
      end
    end
    {false, nil}
  end

  private def apply_favicon_updates(feed_id, url, clear_external, sync_data, update_fav, update_fav_data, clear_fav)
    if clear_external
      @db.exec("UPDATE feeds SET favicon_data = NULL WHERE id = ?", feed_id)
      Log.for("quickheadlines.cache").info { "Cleared external URL from favicon_data for #{url}" }
    end

    if sync_data
      @db.exec("UPDATE feeds SET favicon_data = ? WHERE id = ?", sync_data, feed_id)
      Log.for("quickheadlines.cache").debug { "Synced favicon_data for #{url}: #{sync_data}" }
    end

    if update_fav && update_fav_data
      @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", update_fav, update_fav_data, feed_id)
      Log.for("quickheadlines.cache").debug { "Synced favicon for #{url}" }
    end

    if clear_fav
      @db.exec("UPDATE feeds SET favicon = NULL, favicon_data = NULL WHERE id = ?", feed_id)
      Log.for("quickheadlines.cache").debug { "Cleared missing favicon for #{url}" }
    end
  end

  private def categorize_backfill(feed_id, url, favicon, header_theme_colors, site_link, local_backfills, google_backfills, missing_backfills)
    if header_theme_colors.nil? && favicon && favicon.starts_with?("/favicons/")
      local_backfills << {feed_id, url, favicon}
    elsif header_theme_colors.nil? && favicon && favicon.starts_with?("http") && favicon.includes?("google.com/s2/favicons")
      google_backfills << {feed_id, url, favicon}
    elsif header_theme_colors.nil? && favicon.nil? && site_link && !site_link.empty?
      missing_backfills << {feed_id, url, site_link}
    end
  end

  private def process_google_backfills(backfills : Array({Int64, String, String}))
    backfills.each do |feed_id, url, google_url|
      Fiber.yield
      url_to_fetch = fix_google_favicon_url(google_url, url, feed_id)
      next unless url_to_fetch

      local_path = FaviconStorage.fetch_and_save(url_to_fetch)
      Log.for("quickheadlines.cache").debug { "fetch_and_save returned: #{local_path.inspect}" }
      if local_path
        @mutex.synchronize do
          @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", local_path, local_path, feed_id)
        end
        Log.for("quickheadlines.cache").debug { "Downloaded Google favicon for #{url}: #{local_path}" }
        backfill_header_colors(feed_id, url, local_path)
      else
        log_favicon_failed(feed_id)
      end
    end
  end

  private def fix_google_favicon_url(google_url : String, url : String, feed_id : Int64) : String?
    unless google_url.includes?("domain=#") || google_url.includes?("domain=%23") || google_url.includes?("domain=")
      return google_url
    end

    parsed = URI.parse(url)
    host = parsed.host
    if host && host.includes?(".") && !host.includes?(",") && !host.includes?("#") && !host.includes?("%23")
      fixed = "https://www.google.com/s2/favicons?domain=#{host}&sz=256"
      Log.for("quickheadlines.cache").debug { "Fixed broken domain in Google URL: #{fixed}" }
      return fixed
    end

    Log.for("quickheadlines.cache").debug { "Skipping malformed Google favicon URL: #{google_url}" }
    log_favicon_failed(feed_id)
    nil
  end

  private def process_missing_backfills(backfills : Array({Int64, String, String}))
    backfills.each do |feed_id, url, site_link|
      Fiber.yield
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
            Log.for("quickheadlines.cache").debug { "Backfilled missing favicon for #{url}: #{local_path}" }
            backfill_header_colors(feed_id, url, local_path)
          else
            log_favicon_failed(feed_id)
          end
        end
      rescue ex
        Log.for("quickheadlines.cache").error(exception: ex) { "Backfill missing favicon failed for #{url}" }
        log_favicon_failed(feed_id)
      end
    end
  end

  private def log_favicon_failed(feed_id : Int64) : Nil
    Log.for("quickheadlines.cache").debug { "Favicon fetch failed for feed_id=#{feed_id}" }
  end

  private def backfill_header_colors(feed_id : Int64, feed_url : String, favicon_path : String) : Nil
    @mutex.synchronize do
      extracted = ColorExtractor.extract_theme_colors(favicon_path, feed_url, nil)
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
      else
        normalized = ColorExtractor.normalize_text_value(text_val.to_s)
        text_light = normalized["light"]?
        text_dark = normalized["dark"]?
      end

      legacy_text = text_light || text_dark

      @db.exec("UPDATE feeds SET header_color = ?, header_text_color = ?, header_theme_colors = ? WHERE id = ?",
        bg, legacy_text, theme_json, feed_id)
      Log.for("quickheadlines.cache").debug { "Backfilled header colors for #{feed_url}: bg=#{bg}, text=#{legacy_text}" }
    rescue ex
      Log.for("quickheadlines.cache").error(exception: ex) { "Backfill header colors failed for #{feed_url}" }
    end
  end
end
