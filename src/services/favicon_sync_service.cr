require "db"
require "sqlite3"
require "mutex"
require "openssl"
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
          filename = "#{hash[0...FaviconStorage::HASH_PREFIX_LENGTH]}.#{ext}"
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
          Log.for("quickheadlines.cache").info { "Cleared external URL from favicon_data for #{url}" }
        end

        if sync_favicon_data
          @db.exec("UPDATE feeds SET favicon_data = ? WHERE id = ?", sync_favicon_data, feed_id)
          Log.for("quickheadlines.cache").debug { "Synced favicon_data for #{url}: #{sync_favicon_data}" }
        end

        if update_favicon && update_favicon_data
          @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", update_favicon, update_favicon_data, feed_id)
          Log.for("quickheadlines.cache").debug { "Synced favicon for #{url}: #{favicon}" }
        end

        if clear_favicon
          @db.exec("UPDATE feeds SET favicon = NULL, favicon_data = NULL WHERE id = ?", feed_id)
          Log.for("quickheadlines.cache").debug { "Cleared missing favicon for #{url}" }
        end
      end
    end

    Log.for("quickheadlines.cache").info { "Backfill summary: local=#{local_backfills.size}, google=#{google_backfills.size}, missing=#{missing_backfills.size}" }

    local_backfills.each { |args| backfill_header_colors(*args) }

    google_backfills.each do |feed_id, url, google_url|
      Log.for("quickheadlines.cache").debug { "Processing Google favicon backfill for #{url}: #{google_url}" }
      url_to_fetch = google_url
      if google_url.includes?("domain=#") || google_url.includes?("domain=%23") || google_url.includes?("domain=")
        parsed = URI.parse(url)
        host = parsed.host
        if host && host.includes?(".") && !host.includes?(",") && !host.includes?("#") && !host.includes?("%23")
          url_to_fetch = "https://www.google.com/s2/favicons?domain=#{host}&sz=256"
          Log.for("quickheadlines.cache").debug { "Fixed broken domain in Google URL: #{url_to_fetch}" }
        else
          Log.for("quickheadlines.cache").debug { "Skipping malformed Google favicon URL: #{google_url}" }
          mark_favicon_failed(feed_id)
          next
        end
      end
      local_path = FaviconStorage.fetch_and_save(url_to_fetch)
      Log.for("quickheadlines.cache").debug { "fetch_and_save returned: #{local_path.inspect}" }
      if local_path
        @mutex.synchronize do
          @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", local_path, local_path, feed_id)
        end
        Log.for("quickheadlines.cache").debug { "Downloaded Google favicon for #{url}: #{local_path}" }
        backfill_header_colors(feed_id, url, local_path)
      else
        mark_favicon_failed(feed_id)
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
            Log.for("quickheadlines.cache").debug { "Backfilled missing favicon for #{url}: #{local_path}" }
            backfill_header_colors(feed_id, url, local_path)
          else
            mark_favicon_failed(feed_id)
          end
        end
      rescue ex
        Log.for("quickheadlines.cache").error(exception: ex) { "Backfill missing favicon failed for #{url}" }
        mark_favicon_failed(feed_id)
      end
    end
  end

  private def mark_favicon_failed(feed_id : Int64) : Nil
    @mutex.synchronize do
      @db.exec("UPDATE feeds SET header_theme_colors = ? WHERE id = ?", "FAILED", feed_id)
    end
    Log.for("quickheadlines.cache").debug { "Marked favicon as failed for feed_id=#{feed_id}" }
  end

  private def backfill_header_colors(feed_id : Int64, feed_url : String, favicon_path : String) : Nil
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
    Log.for("quickheadlines.cache").debug { "Backfilled header colors for #{feed_url}: bg=#{bg}, text=#{legacy_text}" }
  rescue ex
    Log.for("quickheadlines.cache").error(exception: ex) { "Backfill header colors failed for #{feed_url}" }
  end
end
