require "stumpy_png"

module ColorExtractor
  VERSION = "1.0.0"

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

  private def self.calculate_contrasting_text(rgb : Array(Int32)) : String
    r, g, b = rgb
    yiq = (r * 299 + g * 587 + b * 114) / 1000

    if yiq >= 128
      "#1f2937"
    else
      "#ffffff"
    end
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
    end
    nil
  end

  private def self.cache_result(path : String, result : {bg: String, text: String})
    @@cache_mutex.synchronize do
      @@extraction_cache[path] = {bg: result[:bg], text: result[:text], timestamp: Time.local}
    end
  end

  def self.clear_cache
    @@cache_mutex.synchronize do
      @@extraction_cache.clear
    end
  end
end
