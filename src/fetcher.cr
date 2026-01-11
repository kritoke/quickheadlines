require "base64"
require "gc"
require "./software_fetcher"

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
        data_uri, timestamp = entry
        if Time.local - timestamp < ENTRY_TTL
          data_uri
        else
          # Expired - calculate size and remove
          @current_size -= data_uri.bytesize
          @cache.delete(url)
          nil
        end
      end
    end
  end

  def set(url : String, data_uri : String) : Nil
    return unless data_uri.starts_with?("data:")

    @mutex.synchronize do
      # Calculate size of new entry
      new_size = data_uri.bytesize

      # Evict if needed
      while @current_size + new_size > CACHE_SIZE_LIMIT && !@cache.empty?
        oldest = @cache.min_by(&.[1][1]).[0]
        @current_size -= @cache[oldest][0].bytesize
        @cache.delete(oldest)
      end

      # Skip if single entry exceeds limit
      return if new_size > CACHE_SIZE_LIMIT

      @cache[url] = {data_uri, Time.local}
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

  loop do
    return if redirects > 10

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
        elsif response.status.success?
          content_type = response.content_type || "image/png"
          memory = IO::Memory.new
          # Limit favicon downloads to 100KB to prevent memory exhaustion
          IO.copy(response.body_io, memory, limit: 100 * 1024)
          return if memory.size == 0
          data = Base64.strict_encode(memory.to_slice)
          return "data:#{content_type};base64,#{data}"
        else
          return
        end
      end
    rescue
      return
    end
  end
end

private def resolve_favicon(feed : Feed, site_link : String, parsed_favicon : String?) : String?
  favicon = parsed_favicon.presence

  # Resolve relative favicon URLs
  if favicon && !favicon.starts_with?("http")
    favicon = resolve_url(favicon, site_link.presence || feed.url)
  end

  if favicon.nil?
    begin
      # Clean up the site link to find a valid host for the favicon fallback
      if host = URI.parse(site_link.gsub(/\/feed\/?$/, "")).host
        favicon = "https://www.google.com/s2/favicons?domain=#{host}&sz=128"
      end
    rescue
    end
  end
  favicon
end

private def get_favicon(feed : Feed, site_link : String, parsed_favicon : String?, previous_data : FeedData?) : {String?, String?}
  favicon = resolve_favicon(feed, site_link, parsed_favicon)

  # Fetch/Cache Favicon Data
  favicon_data = nil
  return {favicon, nil} unless favicon

  # Check the shared cache first
  if cached_data = FAVICON_CACHE.get(favicon)
    favicon_data = cached_data
  elsif previous_data && previous_data.favicon == favicon && (prev_data = previous_data.favicon_data)
    # Use previous data if still valid
    favicon_data = prev_data
    # Store in shared cache
    FAVICON_CACHE.set(favicon, prev_data)
  else
    # Fetch new favicon data
    if new_data = fetch_favicon_uri(favicon)
      favicon_data = new_data
      # Store in shared cache
      FAVICON_CACHE.set(favicon, new_data)
    end
  end

  {favicon, favicon_data}
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
  cache = FeedCache.instance
  if cached = cache.get(feed.url)
    if last_fetched = cache.get_fetched_time(feed.url)
      # Use cache if fresh (within 5 minutes) AND has enough items
      # If cache doesn't have enough items, we need to fetch more (e.g., for "Load More" button)
      if cache_fresh?(last_fetched, 5) && cached.items.size >= item_limit
        # Merge with existing favicon_data if available
        if previous_data && previous_data.favicon_data
          return FeedData.new(
            cached.title,
            cached.url,
            cached.site_link,
            cached.header_color,
            cached.items,
            cached.etag,
            cached.last_modified,
            cached.favicon,
            previous_data.favicon_data
          )
        end
        return cached
      end
    end
  end

  current_url = feed.url
  redirects = 0

  loop do
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
      return error_feed_data(feed, "Error: #{ex.class} - #{ex.message}")
    end
  end
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

  # Do an initial refresh with the active config
  refresh_all(active_config)
  puts "[#{Time.local}] Initial refresh complete"

  # Save initial cache
  save_feed_cache(FeedCache.instance)

  spawn do
    loop do
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
        save_feed_cache(FeedCache.instance)

        # Sleep based on current config's interval
        sleep (active_config.refresh_minutes * 60).seconds
      rescue ex
        puts "Error refresh loop: #{ex.message}"
        sleep 1.minute # Safety sleep so errors don't loop instantly
      end
    end
  end
end
