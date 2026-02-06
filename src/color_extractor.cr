require "stumpy_png"

module ColorExtractor
   VERSION = "2.0.0"

   @@extraction_cache = Hash(String, {bg: String, text: String, timestamp: Time}).new
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

   def self.theme_aware_extract_from_favicon(favicon_path : String, feed_url : String, config_header_color : String?) : Hash(String, String)
     # Check manual override (same as before)
     has_manual_override = !config_header_color.nil? && config_header_color != ""
     return {"dark" => "", "light" => ""} if has_manual_override

     cached = get_cached_theme_aware(favicon_path)
     return cached if cached

     extracted = extract_from_file_theme_aware(favicon_path)
     return {"dark" => "", "light" => ""} unless extracted

     cache_result_theme_aware(favicon_path, extracted)
     extracted
   end

   private def self.extract_from_file_theme_aware(path : String) : Hash(String, String)?
     full_path = "public#{path}"
     return nil unless File.exists?(full_path)

     file_type = `file "#{full_path}"`.strip
     return nil unless file_type.includes?("PNG image data") || file_type.includes?("PNG")
     end

     begin
       canvas = StumpyPNG.read(full_path)
       return nil if canvas.width == 0 || canvas.height == 0

       dominant = calculate_dominant_color(canvas)
       text_colors = theme_aware_text_color(dominant)

       bg_rgb = "rgb(#{dominant[0]}, #{dominant[1]}, #{dominant[2]})"

       {"bg" => bg_rgb, "text" => text_colors.to_json}
    rescue ex
       nil
     end
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

   private def self.get_cached_theme_aware(path : String) : Hash(String, String)?
     @@cache_mutex.synchronize do
       if entry = @@extraction_cache[path]?
         if Time.local - entry[:timestamp] < 7.days
           # Transform old cache format to new format
           if entry[:text] && !entry[:text].includes?("{")
             bg_rgb = parse_rgb_string(entry[:bg] || "")
             if bg_rgb
               entry[:text] = theme_aware_text_color(bg_rgb).to_json
                 @@extraction_cache[path] = entry
             end
           end
         return JSON.parse(entry[:text]).as_h
       else
         @@extraction_cache.delete(path)
       end
     end
     nil
  end

   private def self.get_cached(path : String) : {bg: String?, text: String?}?
     @@cache_mutex.synchronize do
       if entry = @@extraction_cache[path]?
         if Time.local - entry[:timestamp] < 7.days
           return {bg: entry[:bg], text: entry[:text]}
         else
           @@extraction_cache.delete(path)
         end
       end
     nil
  end

   private def self.cache_result_theme_aware(path : String, result : Hash(String, String))
     @@cache_mutex.synchronize do
       @@extraction_cache[path] = {bg: result[:bg], text: result[:text], timestamp: Time.local}
    end
  end

   private def self.cache_result(path : String, result : {bg: String, text: String})
     @@cache_mutex.synchronize do
       @@extraction_cache[path] = {bg: result[:bg], text: result[:text], timestamp: Time.local}
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

   private def self.calculate_luminance(rgb : Array(Int32)) : Float64
     r, g, b = rgb
     (r * 299.0 + g * 587.0 + b * 114.0) / 1000.0
  end

   private def self.calculate_contrasting_text(rgb : Array(Int32)) : String
     lum = calculate_luminance(rgb)

     if lum >= 128
       "#1f2937"
     else
       "#ffffff"
     end
  end

   private def self.theme_aware_text_color(bg_rgb : Array(Int32)) : Hash(String, String)
     lum = calculate_luminance(bg_rgb)
     is_light_bg = lum >= 128

     # Use same dark text for both themes (no white-on-light issue)
     text_dark = "#ffffff"
     text_light = "#1f2937"

     {"dark" => text_dark, "light" => text_light}
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
