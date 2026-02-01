require "base64"
require "gc"
require "./software_fetcher"
require "./favicon_storage"
require "./health_monitor"
require "./config"
require "lexis-minhash"

# ----- Favicon cache with size limits and expiration -----
# Only caches local file paths (not base64 data URIs) to reduce memory usage

# Helper module for generating favicon URLs
module FaviconHelper
  # Generate Google favicon service URL for a given domain
  # Returns nil if domain cannot be extracted
  def self.google_favicon_url(site_link : String, feed_url : String) : String?
    host = site_link.empty? ? feed_url : site_link
    parsed = URI.parse(host)
    return unless parsed_host = parsed.host

    "https://www.google.com/s2/favicons?domain=#{parsed_host}&sz=64"
  rescue ex
    # Invalid URI - return nil
    nil
  end
end

class FaviconCache
  CACHE_SIZE_LIMIT = 10 * 1024 * 1024 # 10MB total (reduced since we only cache paths)
  ENTRY_TTL        = 7.days           # 7 day expiration

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
          # Expired - remove entry
          @current_size -= 1024 # Fixed size for local paths
          @cache.delete(url)
          nil
        end
      end
    end
  end

  def set(url : String, data : String) : Nil
    # Only cache local file paths, not base64 data URIs
    return unless data.starts_with?("/favicons/")

    @mutex.synchronize do
      # Fixed size for local paths (1KB for cache accounting)
      new_size = 1024

      # Evict if needed
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
  current_url = url
  redirects = 0
  start_time = Time.instant

  loop do
    # Timeout after 30 seconds total
    if (Time.instant - start_time).total_seconds > 30
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
          # Always return local path, never base64 data URI
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

  # Ensure both favicon and favicon_data point to local paths
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
    return cached_data
  end

  # Use previous data if still valid and is a local path
  if previous_data && previous_data.favicon == favicon && (prev_data = previous_data.favicon_data)
    if prev_data.starts_with?("/favicons/")
      FAVICON_CACHE.set(favicon, prev_data)
      return prev_data
    end
  end

  # Fetch new favicon data (always returns local path)
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
# Note: This function is deprecated. We now always use local paths.
# This is only called as a safety net for legacy cached data.
private def convert_cached_data_uri(data : String, url : String) : String
  # If we somehow get a data URI, convert it to local path using the feed URL for hashing
  if data.starts_with?("data:image/")
    if converted_url = FaviconStorage.convert_data_uri(data, url)
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

  # Apply authentication if configured
  if auth = feed.auth
    apply_auth_headers(headers, auth)
  end

  if previous_data && current_url == feed.url
    previous_data.etag.try { |v| headers["If-None-Match"] = v }
    previous_data.last_modified.try { |v| headers["If-Modified-Since"] = v }
  end

  headers
end

# Apply authentication headers based on auth type
private def apply_auth_headers(headers : HTTP::Headers, auth : AuthConfig) : Nil
  case auth.type
  when "basic"
    if username = auth.username
      password = auth.password || ""
      credentials = Base64.encode("#{username}:#{password}")
      headers[auth.header] = "#{auth.prefix}#{credentials}"
    end
  when "bearer"
    if token = auth.token
      headers[auth.header] = "#{auth.prefix}#{token}"
    end
  when "apikey"
    if token = auth.token
      headers[auth.header] = "#{auth.prefix}#{token}"
    end
  end
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

  FeedData.new(feed.title, feed.url, site_link, feed.header_color, feed.header_text_color, items, etag, last_modified, favicon, favicon_data)
end

private def error_feed_data(feed : Feed, message : String) : FeedData
  site_link = feed.url

  # Attempt to fetch favicon even on error
  favicon, favicon_data = get_favicon(feed, site_link, nil, nil)

  # If all fallbacks failed, use Google favicon service URL directly
  if favicon.nil? && favicon_data.nil?
    favicon = FaviconHelper.google_favicon_url(site_link, feed.url)
  end

  FeedData.new(
    feed.title,
    feed.url,
    site_link,
    feed.header_color,
    feed.header_text_color,
    [Item.new(message, feed.url, nil)],
    nil, # etag
    nil, # last_modified
    favicon,
    favicon_data
  )
end

# Check if fetch should be aborted due to timeout or retries
private def should_abort_fetch?(feed : Feed, elapsed_seconds : Float, retries : Int32, redirects : Int32, timeout_seconds : Int32) : {Bool, String?}
  if elapsed_seconds > timeout_seconds
    return {true, "Error: Fetch timeout after #{timeout_seconds}s (retries: #{retries})"}
  end

  if redirects > 10
    return {true, "Error: Too many redirects (#{redirects})"}
  end

  if retries >= feed.max_retries
    return {true, "Error: Failed after #{retries} retries"}
  end

  {false, nil}
end

# Calculate backoff time for retry
private def calculate_backoff(feed : Feed, retries : Int32) : Int32
  feed.retry_delay * retries
end

# Handle server error with retry
private def handle_server_error(feed : Feed, retries : Int32, status_code : Int32) : Int32
  new_retries = retries + 1
  backoff_seconds = calculate_backoff(feed, new_retries)
  HealthMonitor.log_warning("fetch_feed(#{feed.url}) server error #{status_code}, retry #{new_retries}/#{feed.max_retries} in #{backoff_seconds}s")
  sleep(backoff_seconds.seconds)
  new_retries
end

# Handle timeout error with retry
private def handle_timeout_error(feed : Feed, retries : Int32) : Int32
  new_retries = retries + 1
  backoff_seconds = calculate_backoff(feed, new_retries)
  HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout, retry #{new_retries}/#{feed.max_retries} in #{backoff_seconds}s")
  sleep(backoff_seconds.seconds)
  new_retries
end

# Handle HTTP response for feed fetching
private def handle_feed_response(feed : Feed, response : HTTP::Client::Response, current_url : String, redirects : Int32, effective_item_limit : Int32, previous_data : FeedData?, cache : FeedCache) : {FeedData?, Int32, Bool, String}
  if response.status.redirection? && (location = response.headers["Location"]?)
    new_url = URI.parse(current_url).resolve(location).to_s
    return {nil, redirects + 1, false, new_url}
  end

  if response.status_code == 304 && previous_data
    return {previous_data, redirects, true, current_url}
  end

  if response.status.success?
    result = handle_success_response(feed, response, effective_item_limit, previous_data)
    cache.add(result)
    return {result, redirects, true, current_url}
  end

  if response.status.server_error?
    return {nil, redirects, false, current_url}
  end

  # Client error - return error, don't retry
  error_result = error_feed_data(feed, "Error fetching feed (status #{response.status_code})")
  {error_result, redirects, true, current_url}
end

  def fetch_feed(feed : Feed, global_item_limit : Int32, previous_data : FeedData? = nil) : FeedData
    # Use feed-specific item limit or global default
    effective_item_limit = feed.item_limit || global_item_limit

  # Check cache first
  if cached_data = get_cached_feed(feed, effective_item_limit, previous_data)
    return cached_data
  end

  cache = FeedCache.instance
  current_url = feed.url
  redirects = 0
  retries = 0
  start_time = Time.instant

  loop do
    # Use feed-specific timeout or default to 60 seconds
    timeout_seconds = feed.timeout > 0 ? feed.timeout : 60

    # Check if we should abort
    elapsed_seconds = (Time.instant - start_time).total_seconds
    abort_msg = should_abort_fetch?(feed, elapsed_seconds, retries, redirects, timeout_seconds)
    if abort_msg[0]
      message = abort_msg[1] || "Error: Unknown fetch error"
      HealthMonitor.log_warning("fetch_feed(#{feed.url}) #{message}")
      return error_feed_data(feed, message)
    end

    begin
      uri = URI.parse(current_url)
      client = create_client(current_url)
      headers = build_fetch_headers(feed, current_url, previous_data)

      client.get(uri.request_target, headers: headers) do |response|
        result, new_redirects, should_return, new_url = handle_feed_response(
          feed, response, current_url, redirects, effective_item_limit, previous_data, cache
        )
        current_url = new_url

        if should_return
          return result.as(FeedData)
        end

        redirects = new_redirects

        # Handle server error with retry
        if response.status.server_error?
          retries = handle_server_error(feed, retries, response.status_code)
        end
      end
    rescue ex : IO::TimeoutError
      # Handle timeout error specifically
      HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout after #{feed.timeout}s")
      HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Timeout)

      retries = handle_timeout_error(feed, retries)
    rescue ex
      # Check if this is a timeout-related error (for other timeout types)
      error_msg = ex.message
      is_timeout = error_msg.is_a?(String) && error_msg.downcase.includes?("timeout")

      if is_timeout
        HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout: #{error_msg}")
        HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Timeout)
        retries = handle_timeout_error(feed, retries)
      else
        HealthMonitor.log_error("fetch_feed(#{feed.url})", ex)
        HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Unreachable)
        return error_feed_data(feed, "Error: #{ex.class} - #{error_msg}")
      end
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
      cached.header_text_color,
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

  STDERR.puts "[#{Time.local}] refresh_all: starting - #{all_configs.size} feeds to fetch"

  # 2. Map existing data for caching (ETags/Last-Modified)
  existing_data = (STATE.feeds + STATE.tabs.flat_map(&.feeds)).index_by(&.url)
  STDERR.puts "[#{Time.local}] refresh_all: existing_data.size=#{existing_data.size}"

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
  success_count = 0
  all_configs.size.times do
    data = channel.receive
    if data && !data.items.empty?
      fetched_map[data.url] = data
      success_count += 1
    else
      STDERR.puts "[#{Time.local}] refresh_all: failed to fetch #{data ? data.url : "unknown"}"
    end
  end

  STDERR.puts "[#{Time.local}] refresh_all: fetched #{fetched_map.size}/#{all_configs.size} feeds successfully"

  # 4. Clear old feed data before replacing to reduce memory pressure
  STDERR.puts "[#{Time.local}] refresh_all: clearing STATE (feeds=#{STATE.feeds.size}, tabs=#{STATE.tabs.size})"
  STATE.feeds.clear
  STATE.tabs.each &.feeds.clear
  STATE.software_releases.clear

  # 5. Populate Top-Level State
  STATE.feeds = config.feeds.map { |feed| fetched_map[feed.url] || error_feed_data(feed, "Failed to fetch") }
  STDERR.puts "[#{Time.local}] refresh_all: STATE.feeds=#{STATE.feeds.size}"
  STATE.software_releases = [] of FeedData
  if sw = config.software_releases
    if sw_box = fetch_sw_with_config(sw, config.item_limit)
      STATE.software_releases << sw_box
    end
  end

  # 6. Populate Tab State
  STATE.tabs = config.tabs.map do |tab_config|
    tab = Tab.new(tab_config.name)
    tab.feeds = tab_config.feeds.map { |feed| fetched_map[feed.url] || error_feed_data(feed, "Failed to fetch") }
    STDERR.puts "[#{Time.local}] refresh_all: tab '#{tab.name}' has #{tab.feeds.size} feeds"
    if sw = tab_config.software_releases
      if sw_box = fetch_sw_with_config(sw, config.item_limit)
        tab.software_releases = [sw_box]
      end
    end
    tab
  end

  STATE.update(Time.local)

  # 7. Process story clustering for all fetched feeds asynchronously
  # Use a channel to limit concurrent clustering jobs (max 10 at a time)
  spawn async_clustering(fetched_map.values.to_a)

  # Clear memory after large amount of data processing
  GC.collect

  STDERR.puts "[#{Time.local}] refresh_all: complete - STATE.feeds=#{STATE.feeds.size}, STATE.tabs=#{STATE.tabs.size}"
end

# ============================================
# Async Story Clustering Functions
# ============================================

# Run clustering asynchronously with concurrency limiting
def async_clustering(feeds : Array(FeedData))
  clustering_channel = Channel(Nil).new(10) # Max 10 concurrent clustering jobs

  spawn do
    feeds.each do |feed_data|
      spawn do
        clustering_channel.send(nil) # Reserve slot
        process_feed_item_clustering(feed_data)
        clustering_channel.receive    # Release slot
      end
    end
  end
end

# Compute cluster assignment for a single item
def compute_cluster_for_item(item_id : Int64, title : String) : Int64?
  # Compute MinHash signature for the title
  document = LexisMinhash::SimpleDocument.new(title)
  signature = LexisMinhash::Engine.compute_signature(document)

  # Store the signature
  FeedCache.instance.store_item_signature(item_id, signature)

  # Generate LSH bands
  bands = LexisMinhash::Engine.generate_bands(signature)
  FeedCache.instance.store_lsh_bands(item_id, bands)

  # Find candidate similar items using LSH
  candidates = FeedCache.instance.find_lsh_candidates(signature)

  # Remove self from candidates
  candidates = candidates.reject { |id| id == item_id }

  if candidates.empty?
    # No similar items found, create a new cluster
    # Use the item_id as the cluster_id (self-referencing)
    FeedCache.instance.assign_cluster(item_id, item_id)
    return item_id
  end

  # Find the most similar candidate
  best_match = nil
  best_similarity = 0.0_f64

  candidates.each do |candidate_id|
    if existing_sig = FeedCache.instance.get_item_signature(candidate_id)
      similarity = LexisMinhash::Engine.similarity(signature, existing_sig)
      if similarity > best_similarity
        best_similarity = similarity
        best_match = candidate_id
      end
    end
  end

  # Check if similarity exceeds threshold
  if best_match && best_similarity >= LexisMinhash::Engine::SIMILARITY_THRESHOLD
    # Get the cluster_id of the best match
    cluster_items = FeedCache.instance.get_cluster_items(best_match)
    if cluster_items.any? { |id| id != best_match }
      # Use the first item in the cluster as the cluster_id
      cluster_id = cluster_items.first
    else
      cluster_id = best_match
    end
    FeedCache.instance.assign_cluster(item_id, cluster_id)
    cluster_id
  else
    # No similar enough match, create new cluster
    FeedCache.instance.assign_cluster(item_id, item_id)
    item_id
  end
end

# Process clustering for all items in a feed
def process_feed_item_clustering(feed_data : FeedData) : Nil
  return if feed_data.items.empty?

  cache = FeedCache.instance

  # Process each item
  feed_data.items.each do |item|
    # Get the item_id from the database
    item_id = cache.get_item_id(feed_data.url, item.link)

    next unless item_id

    # Compute and assign cluster
    compute_cluster_for_item(item_id, item.title)
  end
end

def start_refresh_loop(config_path : String)
  # Load once and set baseline mtime
  active_config = load_config(config_path)
  last_mtime = File.info(config_path).modification_time

  # Do an initial refresh with active config
  refresh_all(active_config)
  puts "[#{Time.local}] Initial refresh complete"

  # Save initial cache
  save_feed_cache(FeedCache.instance, initial_config.cache_retention_hours, initial_config.max_cache_size_mb)

  spawn do
    loop do
      refresh_start_time = Time.instant

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
  save_feed_cache(FeedCache.instance, active_config.cache_retention_hours, active_config.max_cache_size_mb)

        # Check if refresh took too long (potential hang)
        refresh_duration = (Time.instant - refresh_start_time).total_seconds
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
