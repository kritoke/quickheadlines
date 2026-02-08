require "stumpy_png"
require "crimage"
require "json"

module ColorExtractor
  VERSION = "2.0.0"

  @@extraction_cache = Hash(String, {bg: String, text: String | Hash(String, String), timestamp: Time}).new
  @@cache_mutex = Mutex.new

  def self.extract_from_favicon(favicon_path : String, feed_url : String, config_header_color : String?) : {bg: String?, text: String?}
    has_manual_override = !config_header_color.nil? && config_header_color != ""
    return {bg: nil, text: nil} if has_manual_override

    cached = get_cached(favicon_path)
    return cached if cached

    extracted = extract_from_file(favicon_path)
    return {bg: nil, text: nil} unless extracted

    cache_result(favicon_path, extracted)
    extracted
  end

  def self.theme_aware_extract_from_favicon(favicon_path : String, feed_url : String, config_header_color : String?) : Hash(String, String | Hash(String, String))?
    # If a manual header color override is configured, don't compute theme-aware colors here.
    # Return nil so callers fall back to legacy override handling.
    has_manual_override = !config_header_color.nil? && config_header_color != ""
    return nil if has_manual_override

    cached = get_cached_theme_aware(favicon_path)
    return cached if cached

    extracted = extract_from_file_theme_aware(favicon_path)
    return nil unless extracted

    cache_result_theme_aware(favicon_path, extracted)
    extracted
  end

  private def self.get_cached_theme_aware(path : String) : Hash(String, String | Hash(String, String))?
    @@cache_mutex.synchronize do
      if entry = @@extraction_cache[path]?
        # entry[:timestamp] is Time
        if (Time.local - entry[:timestamp]).to_i < 7 * 24 * 60 * 60
          # entry[:text] may be a Hash(String, String) (new format) or a String (legacy)
          text_val = entry[:text]

          text_hash = if text_val.is_a?(Hash)
                        # Already canonical
                        text_val.as(Hash(String, String))
                      elsif text_val.is_a?(String)
                        # Try to parse JSON string produced by older code paths
                        begin
                          tmp = JSON.parse(text_val.to_s).as_h
                          normalized = {} of String => String
                          tmp.each do |k, v|
                            normalized[k.to_s] = v.to_s
                          end
                          normalized
                        rescue
                          # If parsing fails, fall back to mapping the legacy text into both roles
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

  private def self.extract_from_file_theme_aware(path : String) : Hash(String, String | Hash(String, String))?
    full_path = "public#{path}"
    return nil unless File.exists?(full_path)

    begin
      # If ICO, iterate frames and pick the best (most opaque / largest) frame.
      if full_path.downcase.ends_with?(".ico")
        begin
          icon = CrImage::ICO.read_all(full_path)
        rescue
          # Fall back to generic read if ICO reader fails
          icon = nil
        end

        if icon
          best_rgb : Array(Int32)? = nil
          best_opaque : Int32 = -1
          best_area : Int32 = -1

          icon.images.each do |img|
            rgb, opaque = dominant_from_crimage(img)
            next if rgb.nil?

            area = img.bounds.width * img.bounds.height
            if opaque > best_opaque || (opaque == best_opaque && area > best_area)
              best_rgb = rgb
              best_opaque = opaque
              best_area = area
            end
          end

          return nil if best_rgb.nil?

          text_colors = theme_aware_text_color(best_rgb)
          bg_rgb = "rgb(#{best_rgb[0]}, #{best_rgb[1]}, #{best_rgb[2]})"
          return {"bg" => bg_rgb, "text" => text_colors}
        end
      end

      # Generic image path: read with CrImage and compute dominant color
      img = CrImage.read(full_path)
      w = img.bounds.width
      h = img.bounds.height
      return nil if w == 0 || h == 0

      dominant, _opaque = dominant_from_crimage(img)
      return nil if dominant.nil?

      text_colors = theme_aware_text_color(dominant) # Hash(String, String)
      bg_rgb = "rgb(#{dominant[0]}, #{dominant[1]}, #{dominant[2]})"
      {"bg" => bg_rgb, "text" => text_colors}
    rescue e
      nil
    end
  end

  # Compute an (r,g,b) dominant color and count of opaque-ish pixels from a CrImage image.
  private def self.dominant_from_crimage(img) : Tuple(Array(Int32)?, Int32)
    w = img.bounds.width
    h = img.bounds.height
    return {nil, 0} if w == 0 || h == 0

    sample_size = 1000
    step = ((w * h) / sample_size).to_i32
    step = 1 if step < 1

    r_total = 0_i32
    g_total = 0_i32
    b_total = 0_i32
    count = 0_i32
    opaque_count = 0_i32

    i = 0_i32
    (0...h).each do |y|
      (0...w).each do |x|
        if (i % step) == 0
          r32, g32, b32, a32 = img.at(x + img.bounds.min.x, y + img.bounds.min.y).rgba
          r8 = ((r32 >> 8) & 0xff).to_u8
          g8 = ((g32 >> 8) & 0xff).to_u8
          b8 = ((b32 >> 8) & 0xff).to_u8
          a8 = ((a32 >> 8) & 0xff).to_u8

          # count opaque-ish pixels (threshold to consider a pixel solid)
          opaque_count += 1 if a8 >= 200_u8

          next if a8 == 0_u8

          r = r8.to_i32
          g = g8.to_i32
          b = b8.to_i32

          if a8 != 255_u8
            af = a8.to_f / 255.0
            if af > 0.0
              r = (r.to_f / af).to_i32.clamp(0, 255)
              g = (g.to_f / af).to_i32.clamp(0, 255)
              b = (b.to_f / af).to_i32.clamp(0, 255)
            end
          end

          r_total += r
          g_total += g
          b_total += b
          count += 1
        end
        i += 1
      end
    end

    return {nil, opaque_count} if count == 0

    {[(r_total / count).to_i32, (g_total / count).to_i32, (b_total / count).to_i32], opaque_count}
  end

  private def self.parse_rgb_string(str : String) : Array(Int32)?
    return nil unless str.starts_with?("rgb(")

    clean = str.sub("rgb(", "").sub(")", "").sub(" ", "")
    parts = clean.split(",")
    return nil unless parts.size == 3

    r = parts[0].to_i32?
    g = parts[1].to_i32?
    b = parts[2].to_i32?
    return nil unless r && g && b
    [r, g, b]
  end

  private def self.parse_hex_string(str : String) : Array(Int32)?
    s = str.strip
    s = s[1..-1] if s.starts_with?("#")
    return nil unless s.size == 6
    begin
      r = s[0..1].to_i(16).to_i32
      g = s[2..3].to_i(16).to_i32
      b = s[4..5].to_i(16).to_i32
      [r, g, b]
    rescue
      nil
    end
  end

  private def self.parse_color_to_rgb(str : String) : Array(Int32)?
    return nil if str.nil? || str.empty?
    s = str.to_s.strip
    if s.starts_with?("rgb(")
      return parse_rgb_string(s)
    elsif s.starts_with?("#")
      return parse_hex_string(s)
    else
      # Try hex without #
      return parse_hex_string("#" + s) if s =~ /^[0-9a-fA-F]{6}$/
    end
    nil
  end

  private def self.cache_result_theme_aware(path : String, result : Hash(String, String | Hash(String, String)))
    @@cache_mutex.synchronize do
      # Normalize stored bg/text types for backward compatibility
      bg_val = result["bg"] ? result["bg"].to_s : ""
      text_val = result["text"]

      # If text_val is JSON::Any wrapping a Hash, attempt to convert to Hash(String, String)
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

  private def self.cache_result(path : String, result : {bg: String, text: String})
    @@cache_mutex.synchronize do
      @@extraction_cache[path] = {bg: result[:bg], text: result[:text], timestamp: Time.local}
    end
  end

  private def self.get_cached(path : String) : {bg: String?, text: String?}?
    @@cache_mutex.synchronize do
      if entry = @@extraction_cache[path]?
        if (Time.local - entry[:timestamp]).to_i < 7 * 24 * 60 * 60
          # Return stored strings directly. If entry[:text] contains a JSON
          # theme-aware payload, callers will handle parsing as needed.
          return {bg: entry[:bg], text: entry[:text]}
        else
          @@extraction_cache.delete(path)
        end
      end
    end
    nil
  end

  private def self.extract_from_file(path : String) : {bg: String, text: String}?
    full_path = "public#{path}"
    return nil unless File.exists?(full_path)

    # Only process PNG files (StumpyPNG only handles PNG)
    # For non-PNG files (GIF, etc.), skip server-side extraction
    # and let JavaScript ColorThief handle it client-side
    file_type = `file "#{full_path}"`.strip
    unless file_type.includes?("PNG image data") || file_type.includes?("PNG")
      return nil
    end

    begin
      canvas = StumpyPNG.read(full_path)
      width = canvas.width
      height = canvas.height

      return nil if width == 0 || height == 0

      dominant = calculate_dominant_color(canvas)
      text_color = calculate_contrasting_text(dominant)

      bg_rgb = "rgb(#{dominant[0]}, #{dominant[1]}, #{dominant[2]})"

      {bg: bg_rgb, text: text_color}
    rescue ex
      nil
    end
  end

  private def self.calculate_dominant_color(canvas : StumpyPNG::Canvas) : Array(Int32)
    width = canvas.width
    height = canvas.height

    return [0, 0, 0] of Int32 if width == 0 || height == 0

    sample_size = 1000
    step_x = ((width * height) / sample_size).to_i32
    step_x = 1 if step_x < 1

    r_total = 0
    g_total = 0
    b_total = 0
    count = 0

    (0...width).each do |x|
      (0...height).each do |y|
        next unless (x + y * width) % step_x == 0

        pixel = canvas[x, y]
        r, g, b = pixel.to_rgb8

        r_total += r
        g_total += g
        b_total += b
        count += 1
      end
    end

    return [0, 0, 0] of Int32 if count == 0

    r_avg = (r_total / count).to_i32
    g_avg = (g_total / count).to_i32
    b_avg = (b_total / count).to_i32

    [r_avg, g_avg, b_avg]
  end

  private def self.calculate_dominant_color_from_buffer(pixels : Array(UInt8), width : Int32, height : Int32) : Array(Int32)
    return [0, 0, 0] of Int32 if width == 0 || height == 0

    total = 0
    r_total = 0
    g_total = 0
    b_total = 0

    sample_size = 1000
    step = ((width * height) / sample_size).to_i32
    step = 1 if step < 1

    i = 0
    (0...height).each do |y|
      (0...width).each do |x|
        if (i % step) == 0
          idx = (y * width + x) * 4
          a = pixels[idx + 3]
          # skip fully transparent pixels
          next if a == 0_u8
          r = pixels[idx].to_i32
          g = pixels[idx + 1].to_i32
          b = pixels[idx + 2].to_i32
          # If alpha not 255, un-premultiply
          if a != 255_u8
            af = a.to_f / 255.0
            r = (r.to_f / af).to_i32.clamp(0, 255)
            g = (g.to_f / af).to_i32.clamp(0, 255)
            b = (b.to_f / af).to_i32.clamp(0, 255)
          end
          r_total += r
          g_total += g
          b_total += b
          total += 1
        end
        i += 1
      end
    end

    return [0, 0, 0] of Int32 if total == 0
    [(r_total / total).to_i32, (g_total / total).to_i32, (b_total / total).to_i32]
  end

  private def self.calculate_luminance(rgb : Array(Int32)) : Float64
    r, g, b = rgb
    # Use WCAG relative luminance (linearized sRGB)
    to_linear = ->(c : Int32) do
      v = c.to_f / 255.0
      if v <= 0.03928
        v / 12.92
      else
        ((v + 0.055) / 1.055) ** 2.4
      end
    end

    r_l = to_linear.call(r)
    g_l = to_linear.call(g)
    b_l = to_linear.call(b)

    0.2126 * r_l + 0.7152 * g_l + 0.0722 * b_l
  end

  private def self.contrast_ratio(fg : Array(Int32), bg : Array(Int32)) : Float64
    lf = calculate_luminance(fg)
    lb = calculate_luminance(bg)
    l1 = lf > lb ? lf : lb
    l2 = lf > lb ? lb : lf
    (l1 + 0.05) / (l2 + 0.05)
  end

  private def self.rgb_to_hex(rgb : Array(Int32)) : String
    sprintf("#%02x%02x%02x", rgb[0], rgb[1], rgb[2])
  end

  private def self.gray_rgb(v : Int32) : Array(Int32)
    [v, v, v]
  end

  private def self.find_dark_text_for_bg(bg : Array(Int32), threshold : Float64 = 4.5) : Array(Int32)
    # dark text: search from black upwards until contrast >= threshold
    (0..255).step(5) do |val|
      candidate = gray_rgb(val)
      if contrast_ratio(candidate, bg) >= threshold
        return candidate
      end
    end
    # fallback to nearly-black
    gray_rgb(17)
  end

  private def self.find_light_text_for_bg(bg : Array(Int32), threshold : Float64 = 4.5) : Array(Int32)
    # light text: search from white downwards until contrast >= threshold
    val = 255
    while val >= 0
      candidate = gray_rgb(val)
      if contrast_ratio(candidate, bg) >= threshold
        return candidate
      end
      val -= 5
    end
    # fallback to nearly-white
    gray_rgb(238)
  end

  # Public wrappers for testing/consumers
  def self.luminance(rgb : Array(Int32)) : Float64
    calculate_luminance(rgb)
  end

  def self.contrast(fg : Array(Int32), bg : Array(Int32)) : Float64
    contrast_ratio(fg, bg)
  end

  def self.find_dark_text_for_bg_public(bg : Array(Int32)) : String
    rgb_to_hex(find_dark_text_for_bg(bg))
  end

  def self.find_light_text_for_bg_public(bg : Array(Int32)) : String
    rgb_to_hex(find_light_text_for_bg(bg))
  end

  def self.rgb_to_hex_public(rgb : Array(Int32)) : String
    rgb_to_hex(rgb)
  end

  private def self.calculate_contrasting_text(rgb : Array(Int32)) : String
    lum = calculate_luminance(rgb)

    if lum >= 128
      "#1f2937"
    else
      "#ffffff"
    end
  end

  # Ensure theme JSON contains readable text colors relative to bg.
  # Accepts theme_json (String) or nil and optional legacy header_color/text_color.
  # Returns possibly-modified theme JSON string (or nil).
  def self.auto_correct_theme_json(theme_json : String?, legacy_bg : String?, legacy_text : String?) : String?
    begin
      parsed = nil.as(JSON::Any?)
      if theme_json && !theme_json.empty?
        parsed = JSON.parse(theme_json) rescue nil
      end

      # Build a canonical structure: {"bg": "rgb(...)" or "#rrggbb", "text": {"light": "#..","dark":"#.."}, "source": "..."}
      bg_rgb = nil.as(Array(Int32)?)
      text_hash = {} of String => String
      source = nil.as(String?)

      if parsed
        # parsed may be JSON::Any wrapping object
        if parsed.is_a?(JSON::Any)
          h = parsed.as_h rescue nil
          if h
            bg_val = h["bg"] || h["background"]
            source = h["source"]? ? h["source"].to_s : nil
            if bg_val
              bg_rgb = parse_color_to_rgb(bg_val.to_s)
            end
            txt = h["text"]
            if txt.is_a?(Hash) || txt.is_a?(JSON::Any)
              begin
                txt_h = txt.is_a?(JSON::Any) ? txt.as_h : txt.as_h
                txt_h.each do |k, v|
                  text_hash[k.to_s] = v.to_s
                end
              rescue
              end
            elsif txt
              # single string
              text_hash["light"] = txt.to_s
              text_hash["dark"] = txt.to_s
            end
          end
        end
      end

      # If the parsed payload already contains both explicit `light` and
      # `dark` text roles, preserve the incoming JSON unchanged. Auto-correction
      # should not overwrite an explicit two-role payload at write-time; callers
      # that wish to upgrade `source` from "auto" to "auto-corrected" should
      # use `auto_upgrade_to_auto_corrected` instead.
      if parsed && text_hash.has_key?("light") && text_hash.has_key?("dark")
        return nil
      end

      # Fallback to legacy header_color/header_text_color
      if !bg_rgb && legacy_bg
        bg_rgb = parse_color_to_rgb(legacy_bg)
      end
      if text_hash.empty? && legacy_text
        text_hash["light"] = legacy_text
        text_hash["dark"] = legacy_text
      end

      return nil unless bg_rgb

      # Normalize candidate list: try header_text_color, then theme text candidates
      candidates = [] of {key: String, rgb: Array(Int32)}
      if legacy_text
        if rgb = parse_color_to_rgb(legacy_text)
          candidates << {key: "legacy", rgb: rgb}
        end
      end
      text_hash.each do |k, v|
        if rgb = parse_color_to_rgb(v)
          candidates << {key: k, rgb: rgb}
        end
      end

      # Evaluate contrasts
      good_candidates = [] of {key: String, rgb: Array(Int32), contrast: Float64}
      candidates.each do |candidate|
        cr = contrast_ratio(candidate[:rgb], bg_rgb)
        if cr >= 4.5
          good_candidates << {key: candidate[:key], rgb: candidate[:rgb], contrast: cr}
        end
      end

      corrected = false
      if good_candidates.size > 0
        # Prefer legacy if it's good; otherwise pick the highest contrast
        pick = good_candidates.find { |g| g[:key] == "legacy" } || good_candidates.max_by { |cand| cand[:contrast] }
        chosen_hex = rgb_to_hex(pick[:rgb])
        # Ensure both roles are filled: light/dark
        out_text = {"light" => chosen_hex, "dark" => chosen_hex}
      else
        # No candidate meets threshold — generate best dark and light and pick the one with higher contrast
        dark_rgb = find_dark_text_for_bg(bg_rgb)
        light_rgb = find_light_text_for_bg(bg_rgb)
        dark_contrast = contrast_ratio(dark_rgb, bg_rgb)
        light_contrast = contrast_ratio(light_rgb, bg_rgb)
        if dark_contrast >= light_contrast
          chosen_hex = rgb_to_hex(dark_rgb)
        else
          chosen_hex = rgb_to_hex(light_rgb)
        end
        out_text = {"light" => chosen_hex, "dark" => chosen_hex}
        corrected = true
      end

      # Build final payload
      final = {"bg" => (bg_rgb ? rgb_to_hex(bg_rgb) : nil), "text" => out_text}
      # If original source was already auto-corrected/backfill, keep it unless we just corrected
      final_source = corrected ? "auto-corrected" : (source || "auto")
      final["source"] = final_source

      final.to_json
    rescue
      nil
    end
  end

  # Upgrade existing theme JSON entries that were marked as "auto" to
  # "auto-corrected" when their light/dark text roles already meet
  # contrast requirements relative to the bg. Returns a JSON string with
  # source set to "auto-corrected" when an upgrade is performed, or nil
  # otherwise.
  def self.auto_upgrade_to_auto_corrected(theme_json : String?) : String?
    begin
      return nil unless theme_json && !theme_json.empty?
      parsed = JSON.parse(theme_json) rescue nil
      return nil unless parsed.is_a?(JSON::Any)
      h = parsed.as_h rescue nil
      return nil unless h

      src = h["source"]? ? h["source"].to_s : nil
      return nil unless src == "auto"

      bg_val = h["bg"] || h["background"]
      return nil unless bg_val
      bg_rgb = parse_color_to_rgb(bg_val.to_s)
      return nil unless bg_rgb

      txt = h["text"]
      txt_h = {} of String => String
      if txt.is_a?(Hash) || txt.is_a?(JSON::Any)
        begin
          tmp = txt.is_a?(JSON::Any) ? txt.as_h : txt.as_h
          tmp.each do |k, v|
            txt_h[k.to_s] = v.to_s
          end
        rescue
        end
      elsif txt
        txt_h["light"] = txt.to_s
        txt_h["dark"] = txt.to_s
      end

      # Ensure both roles present and meet contrast
      light_ok = false
      dark_ok = false
      if l = txt_h["light"]
        if lrgb = parse_color_to_rgb(l)
          light_ok = contrast_ratio(lrgb, bg_rgb) >= 4.5
        end
      end
      if d = txt_h["dark"]
        if drgb = parse_color_to_rgb(d)
          dark_ok = contrast_ratio(drgb, bg_rgb) >= 4.5
        end
      end

      if light_ok && dark_ok
        # Build upgraded payload preserving original bg string
        final = {"bg" => bg_val.to_s, "text" => {"light" => txt_h["light"], "dark" => txt_h["dark"]}, "source" => "auto-corrected"}
        return final.to_json
      end

      nil
    rescue
      nil
    end
  end

  private def self.theme_aware_text_color(bg_rgb : Array(Int32)) : Hash(String, String)
    # bg_rgb is [r,g,b]
    # For light theme (we render dark text on light backgrounds): choose dark text
    dark_text_rgb = find_dark_text_for_bg(bg_rgb)
    # For dark theme (we render light text on dark backgrounds): choose light text
    light_text_rgb = find_light_text_for_bg(bg_rgb)

    {"dark" => rgb_to_hex(light_text_rgb), "light" => rgb_to_hex(dark_text_rgb)}
  end

  def self.clear_cache
    @@cache_mutex.synchronize do
      @@extraction_cache.clear
    end
  end

  def self.clear_theme_cache
    @@cache_mutex.synchronize do
      @@extraction_cache.clear
    end
  end
end
