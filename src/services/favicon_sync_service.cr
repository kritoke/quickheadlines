require "db"
require "sqlite3"
require "mutex"
require "uri"
require "../config"
require "../models"
require "../favicon_storage"
require "../color_extractor"

# Struct representing a feed row from the database for favicon sync processing.
private struct FeedFaviconRow
  getter feed_id : Int64
  getter url : String
  getter favicon : String?
  getter favicon_data : String?
  getter header_color : String?
  getter header_theme_colors : String?
  getter site_link : String

  def initialize(
    @feed_id : Int64,
    @url : String,
    @favicon : String?,
    @favicon_data : String?,
    @header_color : String?,
    @header_theme_colors : String?,
    @site_link : String,
  )
  end
end

# Struct holding the result of favicon processing for a single feed.
private struct FaviconUpdateResult
  getter feed_id : Int64
  getter url : String
  getter clear_external : Bool
  getter sync_data : String?
  getter update_favicon : String?
  getter update_favicon_data : String?
  getter clear_favicon : Bool

  def initialize(
    @feed_id : Int64,
    @url : String,
    @clear_external : Bool = false,
    @sync_data : String? = nil,
    @update_favicon : String? = nil,
    @update_favicon_data : String? = nil,
    @clear_favicon : Bool = false,
  )
  end
end

# Struct holding backfill lists categorized by favicon source type.
private struct BackfillLists
  getter local : Array({Int64, String, String})
  getter google : Array({Int64, String, String})
  getter missing : Array({Int64, String, String})

  def initialize(
    @local : Array({Int64, String, String}) = [] of {Int64, String, String},
    @google : Array({Int64, String, String}) = [] of {Int64, String, String},
    @missing : Array({Int64, String, String}) = [] of {Int64, String, String},
  )
  end
end

class FaviconSyncService
  @db : DB::Database
  @mutex : Mutex

  def initialize(@db : DB::Database)
    @mutex = Mutex.new
  end

  def sync_favicon_paths : Nil
    feeds_data = load_feeds_data
    backfills = BackfillLists.new

    feeds_data.each do |row|
      result = process_feed_favicon(row)
      @mutex.synchronize { apply_favicon_updates(result) }

      categorize_backfill(row, backfills)
    end

    Log.for("quickheadlines.cache").info { "Backfill summary: local=#{backfills.local.size}, google=#{backfills.google.size}, missing=#{backfills.missing.size}" }

    backfills.local.each { |args| backfill_header_colors(*args) }
    process_google_backfills(backfills.google)
    process_missing_backfills(backfills.missing)
  end

  private def load_feeds_data : Array(FeedFaviconRow)
    feeds_data = [] of FeedFaviconRow
    @db.query("SELECT id, url, favicon, favicon_data, header_color, header_theme_colors, site_link FROM feeds") do |rows|
      rows.each do
        feeds_data << FeedFaviconRow.new(
          feed_id: rows.read(Int64),
          url: rows.read(String),
          favicon: rows.read(String?),
          favicon_data: rows.read(String?),
          header_color: rows.read(String?),
          header_theme_colors: rows.read(String?),
          site_link: rows.read(String),
        )
      end
    end
    feeds_data
  end

  # ameba:disable Metrics/CyclomaticComplexity
  private def process_feed_favicon(row : FeedFaviconRow) : FaviconUpdateResult
    clear_external = false
    sync_favicon_data = nil
    clear_favicon = false
    update_favicon = nil
    update_favicon_data = nil

    favicon_data = row.favicon_data

    if favicon_data && favicon_data.starts_with?("http")
      clear_external = true
      favicon_data = nil
    end

    if favicon_data && favicon_data.starts_with?("/favicons/")
      favicon_path = FaviconStorage.disk_path(favicon_data)
      unless favicon_path && File.exists?(favicon_path)
        Log.for("quickheadlines.cache").debug { "Missing favicon file on disk for #{row.url}" }
        favicon_data = nil
        clear_favicon = true if row.favicon.try(&.starts_with?("/favicons/"))
      end
    end

    if (fav = row.favicon) && favicon_data.nil? && fav.starts_with?("/favicons/")
      sync_favicon_data = fav
    end

    if (fav = row.favicon) && fav.starts_with?("http") && !fav.includes?("google.com/s2/favicons")
      found_local, local_path = find_local_favicon(fav)
      if found_local
        update_favicon = local_path
        update_favicon_data = local_path
      else
        clear_favicon = true
      end
    end

    FaviconUpdateResult.new(
      feed_id: row.feed_id,
      url: row.url,
      clear_external: clear_external,
      sync_data: sync_favicon_data,
      update_favicon: update_favicon,
      update_favicon_data: update_favicon_data,
      clear_favicon: clear_favicon,
    )
  end

  private def find_local_favicon(favicon : String) : Tuple(Bool, String?)
    hash = FaviconStorage.favicon_hash_for_url(favicon)
    FaviconStorage::POSSIBLE_EXTENSIONS.each do |ext|
      filename = FaviconStorage.favicon_filename(hash, ext)
      filepath = File.join(FaviconStorage.favicon_dir, filename)
      if File.exists?(filepath)
        return {true, "/favicons/#{filename}"}
      end
    end
    {false, nil}
  end

  private def apply_favicon_updates(result : FaviconUpdateResult) : Nil
    if result.clear_external
      @db.exec("UPDATE feeds SET favicon_data = NULL WHERE id = ?", result.feed_id)
      Log.for("quickheadlines.cache").info { "Cleared external URL from favicon_data for #{result.url}" }
    end

    if result.sync_data
      @db.exec("UPDATE feeds SET favicon_data = ? WHERE id = ?", result.sync_data, result.feed_id)
      Log.for("quickheadlines.cache").debug { "Synced favicon_data for #{result.url}: #{result.sync_data}" }
    end

    if result.update_favicon && result.update_favicon_data
      @db.exec("UPDATE feeds SET favicon = ?, favicon_data = ? WHERE id = ?", result.update_favicon, result.update_favicon_data, result.feed_id)
      Log.for("quickheadlines.cache").debug { "Synced favicon for #{result.url}" }
    end

    if result.clear_favicon
      @db.exec("UPDATE feeds SET favicon = NULL, favicon_data = NULL WHERE id = ?", result.feed_id)
      Log.for("quickheadlines.cache").debug { "Cleared missing favicon for #{result.url}" }
    end
  end

  private def categorize_backfill(row : FeedFaviconRow, backfills : BackfillLists) : Nil
    return unless row.header_theme_colors.nil?

    fav = row.favicon
    if !fav
      if row.site_link && !row.site_link.empty?
        backfills.missing << {row.feed_id, row.url, row.site_link}
      end
    elsif fav.starts_with?("/favicons/")
      backfills.local << {row.feed_id, row.url, fav}
    elsif fav.starts_with?("http") && fav.includes?("google.com/s2/favicons")
      backfills.google << {row.feed_id, row.url, fav}
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
    # Compute colors outside mutex — file I/O and image processing are expensive
    extracted = ColorExtractor.extract_theme_colors(favicon_path, feed_url, nil)
    return unless extracted

    bg = extracted["bg"]?.try(&.to_s)
    text_val = extracted["text"]?
    return unless bg || text_val

    theme_json = extracted.to_json
    if text_val.is_a?(Hash)
      text_light = text_val.as(Hash)["light"]?.try(&.to_s)
      text_dark = text_val.as(Hash)["dark"]?.try(&.to_s)
    else
      normalized = ColorExtractor.normalize_text_value(text_val.to_s)
      text_light = normalized["light"]?
      text_dark = normalized["dark"]?
    end

    legacy_text = text_light || text_dark

    # Only hold mutex for the DB write
    @mutex.synchronize do
      @db.exec("UPDATE feeds SET header_color = ?, header_text_color = ?, header_theme_colors = ? WHERE id = ?",
        bg, legacy_text, theme_json, feed_id)
    end
    Log.for("quickheadlines.cache").debug { "Backfilled header colors for #{feed_url}: bg=#{bg}, text=#{legacy_text}" }
  rescue ex
    Log.for("quickheadlines.cache").error(exception: ex) { "Backfill header colors failed for #{feed_url}" }
  end
end
