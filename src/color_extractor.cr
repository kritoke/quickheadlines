require "prismatiq"
require "json"

module ColorExtractor
  VERSION = "3.0.0"

  struct CacheEntry
    property bg : String
    property text : String | Hash(String, String)
    property timestamp : Time
    property access_order : Int64

    def initialize(@bg : String, @text : String | Hash(String, String), @timestamp : Time, @access_order : Int64)
    end
  end

  @@extraction_cache = Hash(String, CacheEntry).new
  @@cache_order = Deque(String).new
  @@cache_mutex = Mutex.new

  @@theme_extractor : PrismatIQ::ThemeExtractor?

  private def self.theme_extractor : PrismatIQ::ThemeExtractor
    @@theme_extractor ||= PrismatIQ::ThemeExtractor.new
  end

  def self.extract_theme_colors(favicon_path : String, feed_url : String, config_header_color : String?) : Hash(String, String | Hash(String, String))?
    has_manual_override = !config_header_color.nil? && config_header_color != ""
    return if has_manual_override

    cached = cached_theme_colors(favicon_path)
    return cached if cached

    full_path = File.join(FaviconStorage.favicon_dir, File.basename(favicon_path))
    return unless File.exists?(full_path)

    result = theme_extractor.extract(full_path)
    return unless result

    extracted = {
      "bg"   => result.bg,
      "text" => {
        "light" => result.text["light"],
        "dark"  => result.text["dark"],
      },
    }

    cache_result_theme(favicon_path, extracted)
    extracted
  end

  private def self.cached_theme_colors(path : String) : Hash(String, String | Hash(String, String))?
    @@cache_mutex.synchronize do
      if entry = @@extraction_cache[path]?
        if (Time.local - entry.timestamp).to_i < QuickHeadlines::Constants::COLOR_CACHE_EXPIRY_DAYS * 24 * 60 * 60
          entry.access_order = Time.utc.to_unix_ms
          text_val = entry.text
          text_hash = normalize_text_value(text_val)
          return {"bg" => entry.bg, "text" => text_hash}
        else
          @@extraction_cache.delete(path)
        end
      end
    end
    nil
  end

  private def self.cache_result_theme(path : String, result : Hash(String, String | Hash(String, String)))
    @@cache_mutex.synchronize do
      evictions_needed = @@extraction_cache.size >= QuickHeadlines::Constants::COLOR_CACHE_MAX_SIZE ? 1 : 0

      if evictions_needed > 0
        lru_key = @@extraction_cache.min_by { |_, v| v.access_order }[0]?
        if lru_key
          @@extraction_cache.delete(lru_key)
        end
      end

      bg_val = result["bg"] ? result["bg"].to_s : ""
      text_val = result["text"]
      stored_text = normalize_text_value_for_storage(text_val)

      @@extraction_cache[path] = CacheEntry.new(bg_val, stored_text, Time.local, Time.utc.to_unix_ms)
    end
  end

  def self.normalize_text_value(text_val : String | Hash(String, String)) : Hash(String, String)
    if text_val.is_a?(Hash)
      text_val.as(Hash(String, String))
    elsif text_val.is_a?(String)
      begin
        tmp = JSON.parse(text_val.to_s).as_h
        normalized = {} of String => String
        tmp.each do |k, v|
          normalized[k.to_s] = v.to_s
        end
        normalized
      rescue JSON::ParseException | TypeCastError
        {"light" => text_val.to_s, "dark" => text_val.to_s}
      end
    else
      {"light" => "", "dark" => ""}
    end
  end

  private def self.normalize_text_value_for_storage(text_val : String | Hash(String, String) | JSON::Any) : String | Hash(String, String)
    if text_val.is_a?(JSON::Any)
      begin
        h = text_val.as_h
        normalized = {} of String => String
        h.each do |k, v|
          normalized[k.to_s] = v.to_s
        end
        normalized
      rescue TypeCastError
        text_val.to_s
      end
    elsif text_val.is_a?(Hash)
      text_val.as(Hash(String, String))
    else
      text_val.to_s
    end
  end
end
