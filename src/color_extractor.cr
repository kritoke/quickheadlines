require "prismatiq"
require "json"

module ColorExtractor
  VERSION = "3.0.0"

  @@extraction_cache = Hash(String, {bg: String, text: String | Hash(String, String), timestamp: Time}).new
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

    full_path = "public#{favicon_path}"
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
        if (Time.local - entry[:timestamp]).to_i < 7 * 24 * 60 * 60
          text_val = entry[:text]

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
                        rescue
                          {"light" => text_val.to_s, "dark" => text_val.to_s}
                        end
                      else
                        {"light" => "", "dark" => ""}
                      end

          return {"bg" => entry[:bg], "text" => text_hash}
        else
          @@extraction_cache.delete(path)
        end
      end
    end
    nil
  end

  private def self.cache_result_theme_aware(path : String, result : Hash(String, String | Hash(String, String)))
    @@cache_mutex.synchronize do
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
                      rescue
                        text_val.to_s
                      end
                    elsif text_val.is_a?(Hash)
                      text_val.as(Hash(String, String))
                    else
                      text_val.to_s
                    end

      @@extraction_cache[path] = {bg: bg_val, text: stored_text, timestamp: Time.local}
    end
  end

  def self.auto_correct_theme_json(theme_json : String?, legacy_bg : String?, legacy_text : String?) : String?
    return unless theme_json || legacy_bg

    bg = extract_background(theme_json)
    text_hash = extract_text_hash(theme_json)

    return if bg.nil? || bg.empty?

    bg_rgb = parse_color_to_rgb(bg)
    return unless bg_rgb

    bg_rgb_obj = PrismatIQ::RGB.new(bg_rgb[0], bg_rgb[1], bg_rgb[2])

    needs_correction = check_accessibility(text_hash, bg_rgb_obj)
    corrected_text = apply_palette_corrections(text_hash, bg_rgb_obj, needs_correction)

    source = needs_correction ? "auto-corrected" : "auto"
    build_theme_json(bg, corrected_text, source)
  end

  private def self.extract_background(theme_json : String?) : String?
    parsed = JSON.parse(theme_json || "{}") rescue nil
    return unless parsed.is_a?(JSON::Any)
    h = parsed.as_h
    bg_val = (h["bg"]?) || (h["background"]?)
    bg_val ? bg_val.to_s : nil
  end

  private def self.extract_text_hash(theme_json : String?) : Hash(String, String)
    parsed = JSON.parse(theme_json || "{}") rescue nil
    return {} of String => String unless parsed.is_a?(JSON::Any)
    h = parsed.as_h
    text_val = h["text"]?
    text_hash = {} of String => String

    if text_val && text_val.is_a?(Hash)
      text_val.as_h.each do |k, v|
        key = k.to_s
        text_hash[key] = v.to_s
        if key == "primary"
          text_hash["light"] = v.to_s
          text_hash["dark"] = v.to_s
        elsif !text_hash.has_key?("light") && !text_hash.has_key?("dark")
          text_hash["light"] = v.to_s if key == "light"
          text_hash["dark"] = v.to_s if key == "dark"
        end
      end
    end
    text_hash
  end

  private def self.check_accessibility(text_hash : Hash(String, String), bg_rgb_obj : PrismatIQ::RGB) : Bool
    needs_correction = false

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

    needs_correction
  end

  private def self.apply_palette_corrections(text_hash : Hash(String, String), bg_rgb_obj : PrismatIQ::RGB, needs_correction : Bool) : Hash(String, String)
    corrected_text = text_hash.dup

    if !text_hash.has_key?("light") || !text_hash.has_key?("dark") || needs_correction
      palette = theme_detector.suggest_text_palette(bg_rgb_obj)
      corrected_text["light"] = palette.primary.to_hex unless corrected_text.has_key?("light")
      corrected_text["dark"] = palette.primary.to_hex unless corrected_text.has_key?("dark")
    end

    corrected_text
  end

  private def self.build_theme_json(bg : String, text_hash : Hash(String, String), source : String) : String
    result = {
      "bg"   => bg,
      "text" => {
        "light" => text_hash["light"],
        "dark"  => text_hash["dark"],
      },
      "source" => source,
    }
    result.to_json
  end

  private def self.parse_color_to_rgb(str : String?) : Array(Int32)?
    return if str.nil? || str.empty?
    s = str.to_s.strip

    parse_rgb_format(s) || parse_hex_format(s)
  end

  private def self.parse_rgb_format(s : String) : Array(Int32)?
    return unless s.starts_with?("rgb(")
    s = s.sub("rgb(", "").sub(")", "").gsub(" ", "")
    parts = s.split(",")
    return unless parts.size == 3
    r = parts[0].to_i32?
    g = parts[1].to_i32?
    b = parts[2].to_i32?
    return unless r && g && b
    [r, g, b]
  end

  private def self.parse_hex_format(s : String) : Array(Int32)?
    hex = extract_hex_digits(s)
    return unless hex && hex.size == 6
    parse_hex_bytes(hex)
  end

  private def self.extract_hex_digits(s : String) : String?
    return s[1..-1] if s.starts_with?("#") && s.size == 7
    return s if s =~ /^[0-9a-fA-F]{6}$/
    nil
  end

  private def self.parse_hex_bytes(hex : String) : Array(Int32)?
    [hex[0..1].to_i(16), hex[2..3].to_i(16), hex[4..5].to_i(16)]
  rescue
    nil
  end

  def self.auto_upgrade_to_auto_corrected(theme_json : String?) : String?
    return unless theme_json

    h = parse_json_hash(theme_json)
    return unless h
    return unless auto_source?(h)

    fixed = theme_extractor.fix_theme(theme_json, nil, nil)
    return unless fixed

    h_fixed = parse_json_hash(fixed)
    return unless h_fixed

    build_upgraded_theme(h_fixed)
  end

  private def self.parse_json_hash(json_str : String) : Hash(String, JSON::Any)?
    parsed = JSON.parse(json_str) rescue nil
    return unless parsed.is_a?(JSON::Any)
    parsed.as_h rescue nil
  end

  private def self.auto_source?(h : Hash(String, JSON::Any)) : Bool
    src = h["source"]? ? h["source"].to_s : nil
    src == "auto"
  end

  private def self.build_upgraded_theme(h_fixed : Hash(String, JSON::Any)) : String
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

  def self.find_dark_text_for_bg_public(bg : Array(Int32)) : String
    rgb_obj = PrismatIQ::RGB.new(bg[0], bg[1], bg[2])
    fg = theme_detector.suggest_foreground(rgb_obj)
    fg.to_hex
  end

  def self.find_light_text_for_bg_public(bg : Array(Int32)) : String
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
