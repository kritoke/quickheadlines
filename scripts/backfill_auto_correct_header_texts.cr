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
  DB.open("sqlite3://#{db_path}") do |db|
    normalized = normalize_feed_url(feed_url)
    existing = db.query_one?("SELECT id FROM feeds WHERE url = ?", normalized, as: {Int64})
    if existing.nil?
      existing = db.query_one?("SELECT id FROM feeds WHERE url = ?", feed_url, as: {Int64})
    end
    if existing
      db.exec("UPDATE feeds SET header_theme_colors = ? WHERE id = ?", theme_json, existing)
      STDERR.puts "[Backfill] Saved header_theme_colors for #{feed_url}"
    else
      STDERR.puts "[Backfill] Warning: Cannot save header_theme_colors - feed not found: #{feed_url}"
    end
  end
end

def main
  puts "Starting backfill: compute & auto-correct header_theme_colors for feeds"

  feeds = {} of String => FeedData
  db_path = get_cache_db_path(nil)
  DB.open("sqlite3://#{db_path}") do |db|
    db.query("SELECT url, title, site_link, header_color, header_text_color, header_theme_colors, favicon, favicon_data FROM feeds") do |rows|
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

  total = feeds.size
  processed = 0
  updated = 0

  feeds.each do |url, feed_data|
    processed += 1
    begin
      # We'll compute/correct even if header_theme_colors exists, but skip if source == auto-corrected
      existing = feed_data.header_theme_colors
      if existing && !existing.empty?
        # If already auto-corrected, skip
        begin
          parsed = JSON.parse(existing) rescue nil
          if parsed.is_a?(JSON::Any) && (parsed.as_h["source"]? && parsed.as_h["source"].to_s == "auto-corrected")
            puts "(#{processed}/#{total}) Skipping #{feed_data.title} — already auto-corrected"
            next
          end
        rescue
        end
      end

      # Prefer favicon_data (local path), fall back to favicon
      favicon_path = feed_data.favicon_data || feed_data.favicon

      # If we don't have a local PNG favicon, try Google favicon fallback (PNG)
      if !(favicon_path && favicon_path.starts_with?("/favicons/") && favicon_path.ends_with?(".png"))
        begin
          # Derive host from feed URL
          host = URI.parse(feed_data.url).host
          if host
            google_url = "https://www.google.com/s2/favicons?domain=#{host}&sz=256"
            puts "(#{processed}/#{total}) Trying Google fallback for #{feed_data.title}: #{google_url}"

            uri = URI.parse(google_url)
            HTTP::Client.get(uri) do |response|
              if response.status.success?
                mem = IO::Memory.new
                IO.copy(response.body_io, mem)
                if mem.size > 0
                  saved = FaviconStorage.save_favicon(google_url, mem.to_slice, "image/png")
                  if saved
                    favicon_path = saved
                    puts "(#{processed}/#{total}) Saved Google favicon to #{saved}"
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
      end

      unless favicon_path && favicon_path.starts_with?("/favicons/")
        puts "(#{processed}/#{total}) Skipping #{feed_data.title} — no local favicon path after fallback"
        next
      end

      full_path = File.join("public", favicon_path)
      unless File.exists?(full_path)
        puts "(#{processed}/#{total}) Skipping #{feed_data.title} — favicon file missing: #{full_path}"
        next
      end

      # Run the theme-aware extractor
      extracted = ColorExtractor.theme_aware_extract_from_favicon(favicon_path, feed_data.url, feed_data.header_color)

      # Build incoming theme_json for auto-correction (if extractor returned values)
      incoming_json = nil.as(String?)
      if extracted && extracted.is_a?(Hash)
        bg = extracted["bg"] ? extracted["bg"].to_s : nil
        txt = extracted["text"]
        text_hash = {} of String => String
        if txt.is_a?(Hash)
          txt.each do |k, v|
            text_hash[k.to_s] = v.to_s
          end
        else
          text_hash["light"] = txt.to_s
          text_hash["dark"] = txt.to_s
        end

        payload = {"bg" => bg, "text" => text_hash, "source" => "backfill"}
        incoming_json = payload.to_json
      else
        # No extractor output — use existing DB values if present
        incoming_json = feed_data.header_theme_colors
      end

      corrected_json = ColorExtractor.auto_correct_theme_json(incoming_json, feed_data.header_color, feed_data.header_text_color)
      if corrected_json
        update_feed_theme_colors_db(feed_data.url, corrected_json)
        puts "(#{processed}/#{total}) Updated #{feed_data.title} — header_theme_colors saved"
        updated += 1
      else
        puts "(#{processed}/#{total}) No extractable theme for #{feed_data.title}"
      end
    rescue ex
      STDERR.puts "Error processing #{feed_data.title} (#{feed_data.url}): #{ex.message}"
    end
  end

  puts "Backfill complete — processed: #{processed}, updated: #{updated}"
end

main
