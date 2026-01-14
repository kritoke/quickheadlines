require "base64"
require "gc"
require "./software_fetcher"
require "./favicon_storage"
require "./health_monitor"

# ----- Favicon cache with size limits and expiration -----

class FaviconCache
  CACHE_SIZE_LIMIT = 100 * 1024 * 1024 # 100MB total
  ENTRY_TTL        = 7.days            # 7 day expiration

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
          # Expired - calculate size and remove
          # For data URIs, use actual size; for local paths, use fixed size
          size = data.starts_with?("data:") ? data.bytesize : 1024
          @current_size -= size
          @cache.delete(url)
          nil
        end
      end
    end
  end

  def set(url : String, data : String) : Nil
    # Cache both base64 data URIs and local file paths
    # Local paths are much smaller, so we can cache more of them
    is_data_uri = data.starts_with?("data:")

    @mutex.synchronize do
      # Calculate size of new entry
      # For local paths, use a small fixed size (1KB) for cache accounting
      new_size = is_data_uri ? data.bytesize : 1024

      # Evict if needed
      while @current_size + new_size > CACHE_SIZE_LIMIT && !@cache.empty?
        oldest = @cache.min_by(&.[1][1]).[0]
        oldest_data = @cache[oldest][0]
        # For data URIs, use actual size; for local paths, use fixed size
        oldest_size = oldest_data.starts_with?("data:") ? oldest_data.bytesize : 1024
        @current_size -= oldest_size
        @cache.delete(oldest)
      end

      # Skip if single entry exceeds limit (only applies to data URIs)
      return if is_data_uri && new_size > CACHE_SIZE_LIMIT

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
  current_url = url
  redirects = 0
  start_time = Time.monotonic

  loop do
    # Timeout after 30 seconds total
    if (Time.monotonic - start_time).total_seconds > 30
      HealthMonitor.log_warning("fetch_favicon_uri(#{url}) timeout after 30s")
      return
    end

    return if redirects > 10

    # Check if we already have this favicon saved (using current URL after redirects)
    if cached_url = FaviconStorage.get_or_fetch(current_url)
      return cached_url
    end

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
          next
        elsif response.status.success?
          content_type = response.content_type || "image/png"
          memory = IO::Memory.new
          # Limit favicon downloads to 100KB to prevent memory exhaustion
          IO.copy(response.body_io, memory, limit: 100 * 1024)
          return if memory.size == 0

          # Save favicon to disk using the final URL (after redirects)
          # This ensures the filename matches the actual image source
          if saved_url = FaviconStorage.save_favicon(current_url, memory.to_slice, content_type)
            return saved_url
          end
        else
          return
        end
      end
    rescue ex
      HealthMonitor.log_error("fetch_favicon_uri(#{url})", ex)
      return
    end
  end
end

private def resolve_favicon(feed : Feed, site_link : String?, parsed_favicon : String?) : String?
  favicon = parsed_favicon.presence

  # Resolve relative favicon URLs
  if favicon && !favicon.starts_with?("http")
    favicon = resolve_url(favicon, site_link.presence || feed.url)
  end

  if favicon.nil? && site_link
    begin
      # Clean up the site link to find a valid host for the favicon fallback
      if host = URI.parse(site_link.gsub(/\/feed\/?$/, "")).host
        # Try favicon.ico directly from the site first
        favicon = "https://#{host}/favicon.ico"

        # Note: We don't pre-check if favicon.ico exists here
        # The fetch_favicon_uri function will handle the actual fetching
        # and will return nil if it fails, allowing fallback to HTML parsing
        # and finally to Google favicon service if needed
      end
    rescue ex
      HealthMonitor.log_error("resolve_favicon(#{feed.url})", ex)
    end
  end
  favicon
end

# Extract favicon URL from HTML by parsing link tags
private def extract_favicon_from_html(site_link : String) : String?
  begin
    # Clean up the site link
    clean_link = site_link.gsub(/\/feed\/?$/, "")
    uri = URI.parse(clean_link)

    client = create_client(clean_link)
    headers = HTTP::Headers{
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept"     => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }

    client.get(uri.request_target, headers: headers) do |response|
      if response.status.success?
        html = response.body_io.gets_to_end

        # Parse HTML to find favicon links
        # Look for: <link rel="icon">, <link rel="shortcut icon">, <link rel="apple-touch-icon">
        favicon_patterns = [
          /<link[^>]+rel=["'](?:shortcut )?icon["'][^>]+href=["']([^"']+)["']/i,
          /<link[^>]+href=["']([^"']+)["'][^>]+rel=["'](?:shortcut )?icon["']/i,
          /<link[^>]+rel=["']apple-touch-icon["'][^>]+href=["']([^"']+)["']/i,
        ]

        favicon_patterns.each do |pattern|
          if match = html.match(pattern)
            favicon_url = match[1]
            # Resolve relative URLs
            if favicon_url.starts_with?("//")
              favicon_url = "https:#{favicon_url}"
            elsif !favicon_url.starts_with?("http")
              favicon_url = resolve_url(favicon_url, clean_link)
            end
            return favicon_url
          end
        end
      end
    end
  rescue ex
    HealthMonitor.log_error("extract_favicon_from_html(#{site_link})", ex)
  end

  nil
end

# Try to fetch favicon from HTML as a fallback
# Returns {favicon_url, favicon_data} tuple
private def try_html_fallback(site_link : String) : {String?, String?}
  begin
    # Try parsing HTML for favicon links
    html_favicon = extract_favicon_from_html(site_link)
    if html_favicon
      if html_data = fetch_favicon_uri(html_favicon)
        FAVICON_CACHE.set(html_favicon, html_data)
        return {html_favicon, html_data}
      end
    end
  rescue ex
    HealthMonitor.log_error("try_html_fallback(#{site_link})", ex)
  end
  {nil, nil}
end

# Try to fetch favicon from Google service as final fallback
# Returns {favicon_url, favicon_data} tuple
private def try_google_fallback(site_link : String) : {String?, String?}
  begin
    if host = URI.parse(site_link.gsub(/\/feed\/?$/, "")).host
      google_favicon = "https://www.google.com/s2/favicons?domain=#{host}&sz=64"
      if google_data = fetch_favicon_uri(google_favicon)
        FAVICON_CACHE.set(google_favicon, google_data)
        return {google_favicon, google_data}
      end
    end
  rescue ex
    HealthMonitor.log_error("try_google_fallback(#{site_link})", ex)
  end
  {nil, nil}
end

private def get_favicon(feed : Feed, site_link : String, parsed_favicon : String?, previous_data : FeedData?) : {String?, String?}
  favicon = resolve_favicon(feed, site_link, parsed_favicon)

  return {favicon, nil} unless favicon

  favicon_data = fetch_favicon_data(favicon, site_link, previous_data)

  # Ensure favicon points to local path if we have local favicon_data
  # This prevents storing external URLs in the database when we have cached files
  if favicon_data && favicon_data.starts_with?("/favicons/")
    favicon = favicon_data
  end

  {favicon, favicon_data}
end

# Fetch favicon data from cache or network
private def fetch_favicon_data(favicon : String, site_link : String?, previous_data : FeedData?) : String?
  # Check shared cache first
  if cached_data = FAVICON_CACHE.get(favicon)
    return convert_cached_data_uri(cached_data)
  end

  # Use previous data if still valid
  if previous_data && previous_data.favicon == favicon && (prev_data = previous_data.favicon_data)
    FAVICON_CACHE.set(favicon, prev_data)
    return convert_cached_data_uri(prev_data)
  end

  # Fetch new favicon data
  if new_data = fetch_favicon_uri(favicon)
    FAVICON_CACHE.set(favicon, new_data)
    return new_data
  end

  # Try fallbacks if site_link is available
  try_favicon_fallbacks(site_link)
end

# Try HTML and Google favicon fallbacks
private def try_favicon_fallbacks(site_link : String?) : String?
  return unless site_link

  # Try HTML parsing first
  _fallback_url, fallback_data = try_html_fallback(site_link)

  # If HTML parsing failed, use Google favicon service as final fallback
  if fallback_data.nil?
    _fallback_url, fallback_data = try_google_fallback(site_link)
  end

  fallback_data
end

# Convert base64 data URI to saved file URL if needed
private def convert_cached_data_uri(data : String) : String
  if data.starts_with?("data:image/")
    if converted_url = FaviconStorage.convert_data_uri(data)
      return converted_url
    end
  end
  data
end

private def build_fetch_headers(feed : Feed, current_url : String, previous_data : FeedData?) : HTTP::Headers
  headers = HTTP::Headers{
    "User-Agent"      => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept"          => "application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.7",
    "Accept-Language" => "en-US,en;q=0.9",
    "Connection"      => "keep-alive",
  }

  if previous_data && current_url == feed.url
    previous_data.etag.try { |v| headers["If-None-Match"] = v }
    previous_data.last_modified.try { |v| headers["If-Modified-Since"] = v }
  end
  headers
end

private def handle_success_response(feed : Feed, response : HTTP::Client::Response, item_limit : Int32, previous_data : FeedData?) : FeedData
  parsed = parse_feed(response.body_io, item_limit)
  items = parsed[:items]
  site_link = parsed[:site_link] || feed.url

  favicon, favicon_data = get_favicon(feed, site_link, parsed[:favicon], previous_data)

  # Capture caching headers
  etag = response.headers["ETag"]?
  last_modified = response.headers["Last-Modified"]?

  if items.empty?
    # Show a single placeholder item linking to the feed itself
    items = [Item.new("No items found (or unsupported format)", feed.url, nil)]
  end

  FeedData.new(feed.title, feed.url, site_link, feed.header_color, items, etag, last_modified, favicon, favicon_data)
end

private def error_feed_data(feed : Feed, message : String) : FeedData
  FeedData.new(
    feed.title,
    feed.url,
    feed.url,
    feed.header_color,
    [Item.new(message, feed.url, nil)]
  )
end

def fetch_feed(feed : Feed, item_limit : Int32, previous_data : FeedData? = nil) : FeedData
  # Check cache first
  if cached_data = get_cached_feed(feed, item_limit, previous_data)
    return cached_data
  end

  cache = FeedCache.instance
  current_url = feed.url
  redirects = 0
  start_time = Time.monotonic

  loop do
    # Timeout after 60 seconds total
    if (Time.monotonic - start_time).total_seconds > 60
      HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout after 60s")
      return error_feed_data(feed, "Error: Fetch timeout")
    end

    return error_feed_data(feed, "Error: Too many redirects") if redirects > 10

    begin
      uri = URI.parse(current_url)

      # Use pooled client for better performance
      client = create_client(current_url)
      headers = build_fetch_headers(feed, current_url, previous_data)

      client.get(uri.request_target, headers: headers) do |response|
        if response.status.redirection? && (location = response.headers["Location"]?)
          current_url = uri.resolve(location).to_s
          redirects += 1
        elsif response.status_code == 304 && previous_data
          # Content hasn't changed, return previous data
          return previous_data
        elsif response.status.success?
          result = handle_success_response(feed, response, item_limit, previous_data)

          # Save to cache
          cache.add(result)

          return result
        else
          # Fall back to an error message in the body box
          return error_feed_data(feed, "Error fetching feed (status #{response.status_code})")
        end
      end
    rescue ex
      HealthMonitor.log_error("fetch_feed(#{feed.url})", ex)
      return error_feed_data(feed, "Error: #{ex.class} - #{ex.message}")
    end
  end
end

# Get cached feed data if available and fresh enough
private def get_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
  cache = FeedCache.instance
  return unless cached = cache.get(feed.url)
  return unless last_fetched = cache.get_fetched_time(feed.url)

  # Use cache if fresh (within 5 minutes) AND has enough items
  # If cache doesn't have enough items, we need to fetch more (e.g., for "Load More" button)
  return unless cache_fresh?(last_fetched, 5) && cached.items.size >= item_limit

  # Merge with existing favicon_data if available
  if previous_data && (prev_favicon_data = previous_data.favicon_data)
    # Use local path for favicon if we have local favicon_data
    favicon = prev_favicon_data.starts_with?("/favicons/") ? prev_favicon_data : cached.favicon
    return FeedData.new(
      cached.title,
      cached.url,
      cached.site_link,
      cached.header_color,
      cached.items,
      cached.etag,
      cached.last_modified,
      favicon,
      prev_favicon_data
    )
  end

  cached
end

def refresh_all(config : Config)
  STATE.config_title = config.page_title
  STATE.config = config

  # 1. Collect all unique feed configurations to fetch
  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }

  # 2. Map existing data for caching (ETags/Last-Modified)
  existing_data = (STATE.feeds + STATE.tabs.flat_map(&.feeds)).index_by(&.url)

  # 3. Fetch all feeds concurrently
  channel = Channel(FeedData).new
  all_configs.each_value do |feed|
    spawn do
      SEM.receive
      begin
        prev = existing_data[feed.url]?
        channel.send(fetch_feed(feed, config.item_limit, prev))
      ensure
        SEM.send(nil)
      end
    end
  end

  fetched_map = {} of String => FeedData
  all_configs.size.times do
    data = channel.receive
    fetched_map[data.url] = data
  end

  # 4. Clear old feed data before replacing to reduce memory pressure
  STATE.feeds.clear
  STATE.tabs.each &.feeds.clear
  STATE.software_releases.clear

  # 5. Populate Top-Level State
  STATE.feeds = config.feeds.map { |feed| fetched_map[feed.url] }
  STATE.software_releases = [] of FeedData
  if sw = config.software_releases
    # Assuming fetch_sw is updated to take SoftwareConfig and limit
    if sw_box = fetch_sw_with_config(sw, config.item_limit)
      STATE.software_releases << sw_box
    end
  end

  # 6. Populate Tab State
  STATE.tabs = config.tabs.map do |tab_config|
    tab = Tab.new(tab_config.name)
    tab.feeds = tab_config.feeds.map { |feed| fetched_map[feed.url] }
    if sw = tab_config.software_releases
      if sw_box = fetch_sw_with_config(sw, config.item_limit)
        tab.software_releases = [sw_box]
      end
    end
    tab
  end

  STATE.update(Time.local)

  # Clear memory after large amount of data processing
  GC.collect
end

def start_refresh_loop(config_path : String)
  # Load once and set baseline mtime
  active_config = load_config(config_path)
  last_mtime = File.info(config_path).modification_time

  # Do an initial refresh with active config
  refresh_all(active_config)
  puts "[#{Time.local}] Initial refresh complete"

  # Save initial cache
  save_feed_cache(FeedCache.instance, active_config.cache_retention_hours)

  spawn do
    loop do
      refresh_start_time = Time.monotonic

      begin
        # Check if config file changed
        current_mtime = File.info(config_path).modification_time

        if current_mtime > last_mtime
          new_config = load_config(config_path)
          active_config = new_config
          last_mtime = current_mtime

          puts "[#{Time.local}] Config change detected. Reloaded feeds.yml"
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed after config change"
        else
          # Periodic refresh with existing config to fetch new items
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed feeds and ran GC"
        end

        # Save cache after each refresh
        save_feed_cache(FeedCache.instance, active_config.cache_retention_hours)

        # Check if refresh took too long (potential hang)
        refresh_duration = (Time.monotonic - refresh_start_time).total_seconds
        if refresh_duration > (active_config.refresh_minutes * 60) * 2
          HealthMonitor.log_warning("Refresh took #{refresh_duration.round(2)}s (expected #{active_config.refresh_minutes * 60}s) - possible hang detected")
        end

        # Sleep based on current config's interval
        sleep (active_config.refresh_minutes * 60).seconds
      rescue ex
        HealthMonitor.log_error("refresh_loop", ex)
        sleep 1.minute # Safety sleep so errors don't loop instantly
      end
    end
  end
end
