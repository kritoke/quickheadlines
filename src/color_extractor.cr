require "prismatiq"
require "json"

module ColorExtractor
  VERSION = "3.0.0"

  MAX_CACHE_SIZE       = 1000
  CACHE_EXPIRY_SECONDS = 7 * 24 * 60 * 60

  struct CacheEntry
    property bg : String
    property text : String | Hash(String, String)
    property timestamp : Time
    property access_order : Int32

    def initialize(@bg : String, @text : String | Hash(String, String), @timestamp : Time, @access_order : Int32)
    end
  end

  @@extraction_cache = Hash(String, CacheEntry).new
  @@cache_order = Deque(String).new
  @@cache_counter = 0
  @@cache_mutex = Mutex.new

  @@theme_extractor : PrismatIQ::ThemeExtractor?
  @@accessibility : PrismatIQ::AccessibilityCalculator?
  @@theme_detector : PrismatIQ::ThemeDetector?

  private def self.theme_extractor : PrismatIQ::ThemeExtractor
    @@theme_extractor ||= PrismatIQ::ThemeExtractor.new
  end

  private def self.accessibility : PrismatIQ::AccessibilityCalculator
    @@accessibility ||= PrismatIQ::AccessibilityCalculator.new
  end

  private def self.theme_detector : PrismatIQ::ThemeDetector
    @@theme_detector ||= PrismatIQ::ThemeDetector.new
  end

  def self.theme_aware_extract_from_favicon(favicon_path : String, feed_url : String, config_header_color : String?) : Hash(String, String | Hash(String, String))?
    has_manual_override = !config_header_color.nil? && config_header_color != ""
    return if has_manual_override

    cached = get_cached_theme_aware(favicon_path)
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

    cache_result_theme_aware(favicon_path, extracted)
    extracted
  end

  private def self.get_cached_theme_aware(path : String) : Hash(String, String | Hash(String, String))?
    @@cache_mutex.synchronize do
      if entry = @@extraction_cache[path]?
        if (Time.local - entry.timestamp).to_i < CACHE_EXPIRY_SECONDS
          entry.access_order = @@cache_counter
          @@cache_counter += 1
          text_val = entry.text

          text_hash = if text_val.is_a?(Hash)
                        text_val.as(Hash(String, String))
                      elsif text_val.is_a?(String)
                        begin
                          tmp = JSON.parse(text_val.to_s).as_h
                          normalized = {} of String => String
                          tmp.each do |k, v|
                            normalized[k.to_s] = v.to_s
                          end
                          normalized
                        rescue ex : JSON::ParseException | TypeCastError
                          {"light" => text_val.to_s, "dark" => text_val.to_s}
                        end
                      else
                        {"light" => "", "dark" => ""}
                      end

          return {"bg" => entry.bg, "text" => text_hash}
        else
          @@extraction_cache.delete(path)
        end
      end
    end
    nil
  end

  private def self.cache_result_theme_aware(path : String, result : Hash(String, String | Hash(String, String)))
    @@cache_mutex.synchronize do
      evictions_needed = @@extraction_cache.size >= MAX_CACHE_SIZE ? 1 : 0

      if evictions_needed > 0
        lru_key = @@extraction_cache.min_by { |_, v| v.access_order }[0]?
        if lru_key
          @@extraction_cache.delete(lru_key)
        end
      end

      bg_val = result["bg"] ? result["bg"].to_s : ""
      text_val = result["text"]

      stored_text = if text_val.is_a?(JSON::Any)
                      begin
                        h = text_val.as_h
                        normalized = {} of String => String
                        h.each do |k, v|
                          normalized[k.to_s] = v.to_s
                        end
                        normalized
                      rescue ex : TypeCastError
                        text_val.to_s
                      end
                    elsif text_val.is_a?(Hash)
                      text_val.as(Hash(String, String))
                    else
                      text_val.to_s
                    end

      @@cache_counter += 1
      @@extraction_cache[path] = CacheEntry.new(bg_val, stored_text, Time.local, @@cache_counter)
    end
  end

  def self.auto_correct_theme_json(theme_json : String?, legacy_bg : String?, legacy_text : String?) : String?
    return unless theme_json || legacy_bg

    parsed = JSON.parse(theme_json || "{}") rescue nil
    return unless parsed

    h = parsed.as_h rescue nil
    return unless h

    bg_val = (h["bg"]?) || (h["background"]?)
    bg = bg_val ? bg_val.to_s : nil
    return if bg.nil? || bg.empty?

    bg_rgb = parse_color_to_rgb(bg)
    return unless bg_rgb

    bg_rgb_obj = PrismatIQ::RGB.new(bg_rgb[0], bg_rgb[1], bg_rgb[2])

    text_val = h["text"]?
    text_hash = parse_text_to_hash(text_val)

    needs_correction = false
    corrected_text = text_hash.dup

    if text_hash.has_key?("light")
      light_rgb = parse_color_to_rgb(text_hash["light"])
      if light_rgb
        light_obj = PrismatIQ::RGB.new(light_rgb[0], light_rgb[1], light_rgb[2])
        needs_correction = true unless accessibility.wcag_aa_compliant?(light_obj, bg_rgb_obj)
      end
    end

    if text_hash.has_key?("dark")
      dark_rgb = parse_color_to_rgb(text_hash["dark"])
      if dark_rgb
        dark_obj = PrismatIQ::RGB.new(dark_rgb[0], dark_rgb[1], dark_rgb[2])
        needs_correction = true unless accessibility.wcag_aa_compliant?(dark_obj, bg_rgb_obj)
      end
    end

    if !text_hash.has_key?("light") || !text_hash.has_key?("dark") || needs_correction
      palette = theme_detector.suggest_text_palette(bg_rgb_obj)
      corrected_text["light"] = palette.primary.to_hex unless corrected_text.has_key?("light")
      corrected_text["dark"] = palette.primary.to_hex unless corrected_text.has_key?("dark")
    end

    source = needs_correction ? "auto-corrected" : "auto"

    {
      "bg"   => bg,
      "text" => {
        "light" => corrected_text["light"],
        "dark"  => corrected_text["dark"],
      },
      "source" => source,
    }.to_json
  end

  private def self.parse_text_to_hash(text_val : JSON::Any?) : Hash(String, String)
    return {} of String => String unless text_val && text_val.is_a?(Hash)

    hash = {} of String => String
    text_val.as_h.each do |k, v|
      key = k.to_s
      value = v.to_s
      hash[key] = value
      if key == "primary"
        hash["light"] = value
        hash["dark"] = value
      end
    end
    hash
  end

  private def self.parse_color_to_rgb(str : String?) : Array(Int32)?
    return if str.nil? || str.empty?
    s = str.to_s.strip

    if s.starts_with?("rgb(")
      s = s.sub("rgb(", "").sub(")", "").gsub(" ", "")
      parts = s.split(",")
      return unless parts.size == 3
      r = parts[0].to_i32?
      g = parts[1].to_i32?
      b = parts[2].to_i32?
      return unless r && g && b
      return [r, g, b]
    end

    if s.starts_with?("#")
      s = s[1..-1] if s.size == 7
      return unless s.size == 6
      begin
        r = s[0..1].to_i(16)
        g = s[2..3].to_i(16)
        b = s[4..5].to_i(16)
        return [r, g, b]
      rescue ex : ArgumentError | IndexError
        return
      end
    end

    if s =~ /^[0-9a-fA-F]{6}$/
      begin
        r = s[0..1].to_i(16)
        g = s[2..3].to_i(16)
        b = s[4..5].to_i(16)
        return [r, g, b]
      rescue ex : ArgumentError | IndexError
        return
      end
    end

    nil
  end

  def self.auto_upgrade_to_auto_corrected(theme_json : String?) : String?
    return unless theme_json

    parsed = JSON.parse(theme_json) rescue nil
    return unless parsed.is_a?(JSON::Any)

    h = parsed.as_h rescue nil
    return unless h

    src = h["source"]? ? h["source"].to_s : nil
    return unless src == "auto"

    bg_val = h["bg"]? || h["background"]?
    return unless bg_val

    fixed = theme_extractor.fix_theme(theme_json, nil, nil)
    return unless fixed

    parsed_fixed = JSON.parse(fixed) rescue nil
    return unless parsed_fixed

    h_fixed = parsed_fixed.as_h rescue nil
    return unless h_fixed

    final = {
      "bg"     => h_fixed["background"]? || h_fixed["bg"],
      "text"   => h_fixed["text"],
      "source" => "auto-corrected",
    }
    final.to_json
  end

  def self.luminance(rgb : Array(Int32)) : Float64
    rgb_obj = PrismatIQ::RGB.new(rgb[0], rgb[1], rgb[2])
    accessibility.relative_luminance(rgb_obj)
  end

  def self.contrast(fg : Array(Int32), bg : Array(Int32)) : Float64
    fg_obj = PrismatIQ::RGB.new(fg[0], fg[1], fg[2])
    bg_obj = PrismatIQ::RGB.new(bg[0], bg[1], bg[2])
    accessibility.contrast_ratio(fg_obj, bg_obj)
  end

  def self.suggest_foreground_for_bg(bg : Array(Int32)) : String
    rgb_obj = PrismatIQ::RGB.new(bg[0], bg[1], bg[2])
    fg = theme_detector.suggest_foreground(rgb_obj)
    fg.to_hex
  end

  def self.rgb_to_hex_public(rgb : Array(Int32)) : String
    rgb_obj = PrismatIQ::RGB.new(rgb[0], rgb[1], rgb[2])
    rgb_obj.to_hex
  end

  def self.test_calculate_dominant_color_from_buffer(pixels : Array(UInt8), width : Int32, height : Int32) : Array(Int32)
    options = PrismatIQ::Options.new(color_count: 1, quality: 10)
    slice = Slice(UInt8).new(pixels.size) { |i| pixels[i] }
    result = PrismatIQ.get_palette_from_buffer(slice, width, height, options)

    if result.empty?
      return [0, 0, 0]
    end

    [result[0].r, result[0].g, result[0].b]
  end

  def self.clear_cache
    @@cache_mutex.synchronize do
      @@extraction_cache.clear
    end
    theme_extractor.clear_cache
  end

  def self.clear_theme_cache
    clear_cache
  end
end
