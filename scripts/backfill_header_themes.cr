#!/usr/bin/env crystal

require "../src/storage"
ENV["SKIP_FEED_CACHE_INIT"] = "1"
require "../src/models"
require "../src/color_extractor"
require "../src/favicon_storage"
require "uri"
require "http/client"

FaviconStorage.init

def update_feed_theme_colors_db(feed_url : String, theme_json : String)
  db_path = get_cache_db_path(nil)
  DB.open("sqlite3://#{db_path}") do |db_conn|
    normalized = normalize_feed_url(feed_url)
    existing = db_conn.query_one?("SELECT id FROM feeds WHERE url = ?", normalized, as: {Int64})
    if existing.nil?
      existing = db_conn.query_one?("SELECT id FROM feeds WHERE url = ?", feed_url, as: {Int64})
    end
    if existing
      db_conn.exec("UPDATE feeds SET header_theme_colors = ? WHERE id = ?", theme_json, existing)
      STDERR.puts "[Backfill] Saved header_theme_colors for #{feed_url}"
    else
      STDERR.puts "[Backfill] Warning: Cannot save header_theme_colors - feed not found: #{feed_url}"
    end
  end
end

def load_feeds_from_db : Hash(String, FeedData)
  feeds = {} of String => FeedData
  db_path = get_cache_db_path(nil)
  DB.open("sqlite3://#{db_path}") do |db_conn|
    db_conn.query("SELECT url, title, site_link, header_color, header_text_color, header_theme_colors, favicon, favicon_data FROM feeds") do |rows|
      rows.each do
        url = rows.read(String)
        title = rows.read(String)
        site_link = rows.read(String?) || ""
        header_color = rows.read(String?)
        header_text_color = rows.read(String?)
        header_theme = rows.read(String?)
        favicon = rows.read(String?)
        favicon_data = rows.read(String?)

        fd = FeedData.new(title, url, site_link, header_color, header_text_color, [] of Item, nil, nil, favicon, favicon_data)
        fd.header_theme_colors = header_theme if header_theme
        feeds[url] = fd
      end
    end
  end
  feeds
end

def try_google_favicon_fallback(feed_data : FeedData, processed : Int32, total : Int32) : String?
  begin
    # Derive host from feed URL
    host = URI.parse(feed_data.url).host
    if host
      google_url = "https://www.google.com/s2/favicons?domain=#{host}&sz=256"
      puts "(#{processed}/#{total}) Trying Google fallback for #{feed_data.title}: #{google_url}"

      uri = URI.parse(google_url)
      # Use URI overload to let HTTP::Client handle TLS/host resolution
      # Use the class helper to GET the full URI (handles TLS automatically)
      HTTP::Client.get(uri) do |response|
        if response.status.success?
          mem = IO::Memory.new
          IO.copy(response.body_io, mem)
          if mem.size > 0
            saved = FaviconStorage.save_favicon(google_url, mem.to_slice, "image/png")
            if saved
              puts "(#{processed}/#{total}) Saved Google favicon to #{saved}"
              saved
            end
          end
        else
          puts "(#{processed}/#{total}) Google fallback failed: #{response.status_code}"
        end
      end
    end
  rescue ex
    STDERR.puts "Google fallback error for #{feed_data.title}: #{ex.message}"
  end
  nil
end

def extract_and_save_theme(feed_data : FeedData, favicon_path : String, processed : Int32, total : Int32) : Bool
  full_path = File.join("public", favicon_path)
  unless File.exists?(full_path)
    puts "(#{processed}/#{total}) Skipping #{feed_data.title} — favicon file missing: #{full_path}"
    return false
  end

  # Run the theme-aware extractor
  extracted = ColorExtractor.extract_theme_colors(favicon_path, feed_data.url, feed_data.header_color)
  if extracted && extracted.is_a?(Hash)
    # Normalize to JSON payload shape { bg: "rgb(...)", text: { light: "#..", dark: "#.." }, source: "backfill" }
    bg = extracted["bg"] ? extracted["bg"].to_s : nil
    text = extracted["text"]
    text_hash = if text.is_a?(Hash)
                  normalized = {} of String => String
                  text.each do |k, v|
                    normalized[k.to_s] = v.to_s
                  end
                  normalized
                else
                  {"light" => text.to_s, "dark" => text.to_s}
                end

    payload = {"bg" => bg, "text" => text_hash, "source" => "backfill"}
    theme_json = payload.to_json

    update_feed_theme_colors_db(feed_data.url, theme_json)
    puts "(#{processed}/#{total}) Updated #{feed_data.title} — header_theme_colors saved"
    true
  else
    puts "(#{processed}/#{total}) No extractable theme for #{feed_data.title}"
    false
  end
end

def main
  puts "Starting backfill: compute header_theme_colors for feeds that lack them"

  feeds = load_feeds_from_db

  total = feeds.size
  processed = 0
  updated = 0

  feeds.each do |_url, feed_data|
    processed += 1
    begin
      # Skip if already present
      existing = feed_data.header_theme_colors
      if existing && !existing.empty?
        puts "(#{processed}/#{total}) Skipping #{feed_data.title} — already has header_theme_colors"
        next
      end

      # Prefer favicon_data (local path), fall back to favicon
      favicon_path = feed_data.favicon_data || feed_data.favicon

      # If we don't have a local PNG favicon, try Google favicon fallback (PNG)
      if !(favicon_path && favicon_path.starts_with?("/favicons/") && favicon_path.ends_with?(".png"))
        favicon_path = try_google_favicon_fallback(feed_data, processed, total)
      end

      unless favicon_path && favicon_path.starts_with?("/favicons/")
        puts "(#{processed}/#{total}) Skipping #{feed_data.title} — no local favicon path after fallback"
        next
      end

      if extract_and_save_theme(feed_data, favicon_path, processed, total)
        updated += 1
      end
    rescue ex
      STDERR.puts "Error processing #{feed_data.title} (#{feed_data.url}): #{ex.message}"
    end
  end

  puts "Backfill complete — processed: #{processed}, updated: #{updated}"
end

main
