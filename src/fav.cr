require "http/client"
require "uri"
require "mutex"
require "./favicon_storage"
require "./health_monitor"

# Validates that data is actually an image by checking magic bytes
private def png_magic?(data : Bytes) : Bool
  data.size >= 8 && data[0..7] == Bytes[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
end

private def jpeg_magic?(data : Bytes) : Bool
  data.size >= 3 && data[0..2] == Bytes[0xFF, 0xD8, 0xFF]
end

private def ico_magic?(data : Bytes) : Bool
  data.size >= 4 && data[0] == 0x00 && data[1] == 0x00 && (data[2] == 0x01 || data[2] == 0x02) && data[3] == 0x00
end

private def svg_magic?(data : Bytes) : Bool
  (data.size >= 5 && data[0..4] == Bytes[0x3C, 0x3F, 0x78, 0x6D, 0x6C]) ||
    (data.size >= 4 && data[0..3] == Bytes[0x3C, 0x73, 0x76, 0x67])
end

private def webp_magic?(data : Bytes) : Bool
  data.size >= 12 && data[0..3] == Bytes[0x52, 0x49, 0x46, 0x46] && data[8..11] == Bytes[0x57, 0x45, 0x42, 0x50]
end

private def valid_image?(data : Bytes) : Bool
  return false if data.size < 4
  png_magic?(data) || jpeg_magic?(data) || ico_magic?(data) || svg_magic?(data) || webp_magic?(data)
end

# Favicon cache (in-memory) for local path references
class FaviconCache
  CACHE_SIZE_LIMIT = 10 * 1024 * 1024
  ENTRY_TTL        = 7.days

  @cache = Hash(String, {String, Time}).new
  @current_size = 0
  @mutex = Mutex.new

  def get(url : String) : String?
    @mutex.synchronize do
      if entry = @cache[url]?
        data, timestamp = entry
        return data if Time.local - timestamp < ENTRY_TTL
        @current_size -= 1024
        @cache.delete(url)
      end
    end
    nil
  end

  def set(url : String, data : String) : Nil
    return unless data.starts_with?("/favicons/")
    @mutex.synchronize do
      new_size = 1024
      while @current_size + new_size > CACHE_SIZE_LIMIT && !@cache.empty?
        oldest = @cache.min_by(&.[1][1]).[0]
        @cache.delete(oldest)
        @current_size -= 1024
      end
      @cache[url] = {data, Time.local}
      @current_size += new_size
    end
  end

  def clear : Nil
    @mutex.synchronize do
      @cache.clear
      @current_size = 0
    end
  end
end

FAVICON_CACHE = FaviconCache.new

module FaviconHelper
  def self.google_favicon_url(site_link : String, feed_url : String) : String?
    host = (site_link.empty? || site_link == "#") ? feed_url : site_link
    parsed = URI.parse(host)
    return unless parsed_host = parsed.host
    "https://www.google.com/s2/favicons?domain=#{parsed_host}&sz=64"
  rescue
    nil
  end
end

# Read response body into memory with a max size
private def read_response_memory(response : HTTP::Client::Response, max_bytes : Int32) : IO::Memory?
  memory = IO::Memory.new
  IO.copy(response.body_io, memory, limit: max_bytes)
  return memory if memory.size > 0
  nil
end

# Detect small gray placeholder and trigger fallback logic
private def try_handle_gray_placeholder(current_url : String, memory : IO::Memory) : String?
  if memory.size == 198
    debug_log("Gray placeholder detected (#{memory.size} bytes) for #{current_url}")
    if current_url.includes?("google.com/s2/favicons")
      larger_url = current_url.gsub(/sz=\d+/, "sz=256")
      cached = FaviconStorage.get_or_fetch(larger_url)
      return cached if cached
      return fetch_favicon_uri(larger_url)
    else
      debug_log("Trying Google fallback for gray placeholder")
      return nil
    end
  end
  nil
end

private def save_favicon_memory(current_url : String, memory : IO::Memory, content_type : String) : String?
  FaviconStorage.save_favicon(current_url, memory.to_slice, content_type)
end

# Extracted helper to handle success-case logic for a favicon response
private def handle_favicon_success(current_url : String, response : HTTP::Client::Response) : String?
  content_type = response.content_type || "image/png"
  memory = read_response_memory(response, 100 * 1024)
  return if memory.nil?

  if handled = try_handle_gray_placeholder(current_url, memory)
    return handled
  end

  unless valid_image?(memory.to_slice)
    debug_log("Invalid favicon content (not an image): #{current_url}")
    return nil
  end

  if saved_url = save_favicon_memory(current_url, memory, content_type)
    return saved_url
  end
  nil
end

# Test helpers (exposed for specs)
def test_png_magic?(data : Bytes) : Bool
  png_magic?(data)
end

def test_jpeg_magic?(data : Bytes) : Bool
  jpeg_magic?(data)
end

def test_ico_magic?(data : Bytes) : Bool
  ico_magic?(data)
end

def test_svg_magic?(data : Bytes) : Bool
  svg_magic?(data)
end

def test_webp_magic?(data : Bytes) : Bool
  webp_magic?(data)
end

def test_try_handle_gray_placeholder(current_url : String, memory : IO::Memory) : String?
  try_handle_gray_placeholder(current_url, memory)
end

private def perform_fetch_once(current_url : String) : Tuple(Symbol, String?)
  uri = URI.parse(current_url)
  client = create_client(current_url)
  headers = HTTP::Headers{
    "User-Agent"      => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language" => "en-US,en;q=0.9",
    "Connection"      => "keep-alive",
  }

  begin
    client.get(uri.request_target, headers: headers) do |response|
      if response.status.redirection? && (location = response.headers["Location"]?)
        return {:redirect, uri.resolve(location).to_s}
      elsif response.status.success?
        saved = handle_favicon_success(current_url, response)
        return {:final, saved}
      else
        # For not_found, forbidden, server errors, or others we treat as final nil
        return {:final, nil}
      end
    end
  rescue ex
    HealthMonitor.log_error("perform_fetch_once(#{current_url})", ex)
    return {:final, nil}
  end
end

def fetch_favicon_uri(url : String) : String?
  debug_log("Fetching favicon: #{url}")
  current_url = url
  redirects = 0
  start_time = Time.monotonic

  loop do
    # Timeout after 30 seconds total
    if (Time.monotonic - start_time).total_seconds > 30
      HealthMonitor.log_warning("fetch_favicon_uri(#{url}) timeout after 30s")
      return
    end

    if redirects > 10
      debug_log("Too many redirects (#{redirects}) for favicon: #{url}")
      return
    end

    # Check if we already have this favicon saved (using current URL after redirects)
    if cached_url = FaviconStorage.get_or_fetch(current_url)
      debug_log("Favicon cache hit: #{current_url}")
      return cached_url
    end

    debug_log("Fetching favicon from: #{current_url}")

    action, value = perform_fetch_once(current_url)
    case action
    when :redirect
      if value
        current_url = value
        redirects += 1
        debug_log("Favicon redirect #{redirects}: #{current_url}")
        next
      else
        return
      end
    when :final
      if value
        debug_log("Favicon saved: #{value}")
        return value
      else
        debug_log("Favicon fetch final result was nil for #{current_url}")
        return nil
      end
    else
      return nil
    end
  end
end
