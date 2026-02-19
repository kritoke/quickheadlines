require "base64"
require "time"
require "mutex"
require "../config"
require "../favicon_storage"
require "../health_monitor"

private def valid_image?(data : Bytes) : Bool
  return false if data.size < 4

  return true if data[0..7] == Bytes[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

  return true if data[0..2] == Bytes[0xFF, 0xD8, 0xFF]

  return true if data[0] == 0x00 && data[1] == 0x00 && (data[2] == 0x01 || data[2] == 0x02) && data[3] == 0x00

  return true if data[0..4] == Bytes[0x3C, 0x3F, 0x78, 0x6D, 0x6C]
  return true if data[0..3] == Bytes[0x3C, 0x73, 0x76, 0x67]

  return true if data[0..3] == Bytes[0x52, 0x49, 0x46, 0x46] && data[8..11] == Bytes[0x57, 0x45, 0x42, 0x50]

  false
end

module FaviconHelper
  def self.google_favicon_url(site_link : String, feed_url : String) : String?
    host = (site_link.empty? || site_link == "#") ? feed_url : site_link
    parsed = URI.parse(host)
    return unless parsed_host = parsed.host

    "https://www.google.com/s2/favicons?domain=#{parsed_host}&sz=64"
  rescue ex
    nil
  end
end

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
        if Time.local - timestamp < ENTRY_TTL
          data
        else
          @current_size -= 1024
          @cache.delete(url)
          nil
        end
      end
    end
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

def fetch_favicon_uri(url : String) : String?
  debug_log("Fetching favicon: #{url}")
  current_url = url
  redirects = 0
  start_time = Time.monotonic

  loop do
    if (Time.monotonic - start_time).total_seconds > 30
      HealthMonitor.log_warning("fetch_favicon_uri(#{url}) timeout after 30s")
      return
    end

    if redirects > 10
      debug_log("Too many redirects (#{redirects}) for favicon: #{url}")
      return
    end

    cached_url = FaviconStorage.get_or_fetch(current_url)
    if cached_url
      debug_log("Favicon cache hit: #{current_url}")
      return cached_url
    end

    debug_log("Fetching favicon from: #{current_url}")

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
          current_url = uri.resolve(location).to_s
          redirects += 1
          debug_log("Favicon redirect #{redirects}: #{current_url}")
          next
        elsif response.status.success?
          content_type = response.content_type || "image/png"
          memory = IO::Memory.new
          IO.copy(response.body_io, memory, limit: 100 * 1024)
          if memory.size == 0
            debug_log("Empty favicon response: #{current_url}")
            return
          end

          if memory.size == 198
            debug_log("Gray placeholder detected (#{memory.size} bytes) for #{current_url}")
            if current_url.includes?("google.com/s2/favicons")
              larger_url = current_url.gsub(/sz=\d+/, "sz=256")
              cached = FaviconStorage.get_or_fetch(larger_url)
              if cached
                return cached
              end
              return fetch_favicon_uri(larger_url)
            else
              debug_log("Trying Google fallback for gray placeholder")
              return nil
            end
          end

          unless valid_image?(memory.to_slice)
            debug_log("Invalid favicon content (not an image): #{current_url}")
            return nil
          end

          debug_log("Favicon fetched: #{current_url}, size=#{memory.size}, type=#{content_type}")

          if saved_url = FaviconStorage.save_favicon(current_url, memory.to_slice, content_type)
            debug_log("Favicon saved: #{saved_url}")
            return saved_url
          else
            debug_log("Favicon save failed: #{current_url}")
            return
          end
        elsif response.status.not_found?
          debug_log("Favicon 404: #{current_url}")
          return
        elsif response.status.forbidden?
          debug_log("Favicon 403: #{current_url}")
          return
        else
          debug_log("Favicon error #{response.status_code}: #{current_url}")
          return
        end
      end
    rescue ex
      HealthMonitor.log_error("fetch_favicon_uri(#{url})", ex)
      debug_log("Favicon fetch error: #{url} - #{ex.message}")
      return
    end
  end
end

private def resolve_favicon(feed : Feed, site_link : String?, parsed_favicon : String?) : String?
  favicon = parsed_favicon.presence

  if favicon && !favicon.starts_with?("http")
    favicon = resolve_url(favicon, site_link.presence || feed.url)
  end

  if favicon.nil? && site_link
    begin
      if host = URI.parse(site_link.gsub(/\/feed\/?$/, "")).host
        favicon_urls = [
          "https://#{host}/favicon.ico",
          "https://#{host}/favicon.png",
          "https://#{host}/apple-touch-icon.png",
          "https://#{host}/apple-touch-icon-180x180.png",
        ]

        favicon_urls.each do |url|
          debug_log("Trying favicon URL: #{url}")
          existing = FaviconStorage.get_or_fetch(url)
          if existing
            debug_log("Found cached favicon: #{url}")
            favicon = url
            break
          end
        end

        if favicon.nil?
          favicon = favicon_urls[0]
        end
      end
    rescue ex
      HealthMonitor.log_error("resolve_favicon(#{feed.url})", ex)
    end
  end
  favicon
end

private def extract_favicon_from_html(site_link : String) : String?
  debug_log("Extracting favicon from HTML: #{site_link}")
  begin
    clean_link = site_link.gsub(/\/feed\/?$/, "")
    debug_log("Fetching HTML from: #{clean_link}")
    uri = URI.parse(clean_link)
    client = create_client(clean_link)
    headers = HTTP::Headers{
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept"     => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }

    client.get(uri.request_target, headers: headers) do |response|
      if response.status.success?
        html = response.body_io.gets_to_end
        debug_log("HTML fetched: #{html.size} bytes")

        favicon_patterns = [
          /<link[^>]+rel=["'](?:shortcut )?icon["'][^>]+href=["']([^"']+)["']/i,
          /<link[^>]+href=["']([^"']+)["'][^>]+rel=["'](?:shortcut )?icon["']/i,
          /<link[^>]+rel=["']apple-touch-icon["'][^>]+href=["']([^"']+)["']/i,
          /<link[^>]+rel=["']apple-touch-icon-precomposed["'][^>]+href=["']([^"']+)["']/i,
          /<link[^>]+type=["']image\/x-icon["'][^>]+href=["']([^"']+)["']/i,
          /<link[^>]+href=["']([^"']+\.ico)["'][^>]+rel=["']icon["']/i,
          /<link[^>]+rel=["']icon["'][^>]+type=["']image\/x-icon["'][^>]+href=["']([^"']+)["']/i,
        ]

        favicon_patterns.each do |pattern|
          if match = html.match(pattern)
            favicon_url = match[1]
            if favicon_url.starts_with?("//")
              favicon_url = "https:#{favicon_url}"
            elsif !favicon_url.starts_with?("http")
              favicon_url = resolve_url(favicon_url, clean_link)
            end
            debug_log("Found favicon in HTML: #{favicon_url}")
            return favicon_url
          end
        end
        debug_log("No favicon link found in HTML")
      elsif response.status.not_found?
        debug_log("HTML fetch 404: #{clean_link}")
      else
        debug_log("HTML fetch error #{response.status_code}: #{clean_link}")
      end
    end
  rescue ex
    HealthMonitor.log_error("extract_favicon_from_html(#{site_link})", ex)
    debug_log("Error extracting favicon: #{ex.message}")
  end

  nil
end

private def try_html_fallback(site_link : String) : {String?, String?}
  debug_log("HTML fallback for: #{site_link}")
  begin
    html_favicon = extract_favicon_from_html(site_link)
    if html_favicon
      debug_log("Found HTML favicon: #{html_favicon}")
      if html_data = fetch_favicon_uri(html_favicon)
        FAVICON_CACHE.set(html_favicon, html_data)
        return {html_favicon, html_data}
      end
    else
      debug_log("No HTML favicon found for: #{site_link}")
    end
  rescue ex
    HealthMonitor.log_error("try_html_fallback(#{site_link})", ex)
  end
  {nil, nil}
end

private def try_google_fallback(site_link : String) : {String?, String?}
  debug_log("Google fallback for: #{site_link}")
  begin
    if host = URI.parse(site_link.gsub(/\/feed\/?$/, "")).host
      google_favicon = "https://www.google.com/s2/favicons?domain=#{host}&sz=256"
      debug_log("Google favicon URL: #{google_favicon}")
      if google_data = fetch_favicon_uri(google_favicon)
        FAVICON_CACHE.set(google_favicon, google_data)
        return {google_favicon, google_data}
      else
        debug_log("Google fallback failed for: #{host}")
      end
    end
  rescue ex
    HealthMonitor.log_error("try_google_fallback(#{site_link})", ex)
  end
  {nil, nil}
end

def get_favicon(feed : Feed, site_link : String, parsed_favicon : String?, previous_data : FeedData?) : {String?, String?}
  favicon = resolve_favicon(feed, site_link, parsed_favicon)

  return {favicon, nil} unless favicon

  favicon_data = fetch_favicon_data(favicon, site_link, previous_data)

  if favicon_data && favicon_data.starts_with?("/favicons/")
    favicon = favicon_data
  end

  {favicon, favicon_data}
end

private def fetch_favicon_data(favicon : String, site_link : String?, previous_data : FeedData?) : String?
  if cached_data = FAVICON_CACHE.get(favicon)
    return cached_data
  end

  if previous_data && previous_data.favicon == favicon && (prev_data = previous_data.favicon_data)
    if prev_data.starts_with?("/favicons/")
      FAVICON_CACHE.set(favicon, prev_data)
      return prev_data
    end
  end

  if new_data = fetch_favicon_uri(favicon)
    FAVICON_CACHE.set(favicon, new_data)
    return new_data
  end

  try_favicon_fallbacks(site_link)
end

private def try_favicon_fallbacks(site_link : String?) : String?
  return unless site_link

  _fallback_url, fallback_data = try_html_fallback(site_link)

  if fallback_data.nil?
    _fallback_url, fallback_data = try_google_fallback(site_link)
  end

  fallback_data
end

private def convert_cached_data_uri(data : String, url : String) : String
  if data.starts_with?("data:image/")
    if converted_url = FaviconStorage.convert_data_uri(data, url)
      return converted_url
    end
  end
  data
end
