require "base64"
require "time"
require "json"
require "fetcher"
require "../config"
require "../constants"
require "../models"
require "../storage"
require "../health_monitor"
require "../color_extractor"
require "./vug_adapter"

# FeedFetcher encapsulates all feed fetching logic with proper dependency injection.
# Use FeedFetcher.instance for singleton access or inject FeedCache for testing.
class FeedFetcher
  @cache : FeedCache

  def initialize(@cache : FeedCache)
  end

  # Singleton accessor for backward compatibility
  @@instance : FeedFetcher?

  def self.instance : FeedFetcher
    @@instance ||= FeedFetcher.new(FeedCache.instance)
  end

  def self.instance=(fetcher : FeedFetcher)
    @@instance = fetcher
  end

  private def should_fallback_to_stale_cache?(result : FeedData, feed : Feed) : Bool
    result.items.size >= 1 &&
      (first_item = result.items.first) &&
      first_item.title.starts_with?("Error:") &&
      first_item.link == feed.url
  end

  private def handle_fetch_exception(ex : Exception, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, retries : Int32) : Tuple(FeedData?, Int32)
    error_msg = ex.message
    is_timeout = error_msg.is_a?(String) && error_msg.downcase.includes?("timeout")

    if is_timeout
      HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout: #{error_msg}")
      HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Timeout)
      {nil, handle_timeout_error(feed, retries)}
    else
      HealthMonitor.log_error("fetch_feed(#{feed.url})", ex)
      HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Unreachable)
      if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
        {stale_cache, retries}
      else
        {build_error_feed_data(feed, "Error: #{ex.class} - #{error_msg}"), retries}
      end
    end
  end

  private def handle_abort_condition(feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, abort_msg : Tuple(Bool, String?)) : FeedData?
    return unless abort_msg[0]

    message = abort_msg[1] || "Error: Unknown fetch error"
    HealthMonitor.log_warning("fetch_feed(#{feed.url}) #{message}")
    if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
      stale_cache
    else
      build_error_feed_data(feed, message)
    end
  end

  private def process_response_result(result_data : FeedData, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?) : FeedData?
    if should_fallback_to_stale_cache?(result_data, feed)
      get_stale_cached_feed(feed, effective_item_limit, previous_data) || result_data
    else
      result_data
    end
  end

  # Main entry point - fetch a feed with caching and retry logic
  def fetch(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
    effective_item_limit = feed.item_limit || display_item_limit

    if cached_data = get_cached_feed(feed, effective_item_limit, previous_data)
      return cached_data
    end

    current_url = feed.url
    redirects = 0
    retries = 0
    start_time = Time.monotonic

    loop do
      timeout_seconds = Constants::FETCH_TIMEOUT_SECONDS
      elapsed_seconds = (Time.monotonic - start_time).total_seconds
      abort_msg = should_abort_fetch?(feed, elapsed_seconds, retries, redirects, timeout_seconds)

      if abort_result = handle_abort_condition(feed, effective_item_limit, previous_data, abort_msg)
        return abort_result
      end

      begin
        result = Fetcher.pull(current_url, HTTP::Headers.new, db_fetch_limit, fetcher_config)

        if result.success?
          items = result.entries.map do |entry|
            comment_url = entry.comment_url || (entry.is_discussion_url ? entry.url : nil)
            Item.new(entry.title, entry.url, entry.published_at, nil, comment_url, entry.commentary_url)
          end

          if items.empty?
            debug_log("Feed returned no items: #{feed.title} (#{feed.url})")
            return build_error_feed_data(feed, "No items found (or unsupported format)")
          end

          site_link = result.site_link || feed.url

          favicon, favicon_data = VugAdapter.get_favicon(site_link, result.favicon, previous_data.try(&.favicon), previous_data.try(&.favicon_data))

          if favicon.nil? && favicon_data.nil?
            google_url = VugAdapter.google_favicon_url(site_link.presence || feed.url)
            if saved = FaviconStorage.fetch_and_save(google_url)
              favicon = saved
              favicon_data = saved
            else
              favicon = google_url
            end
          end

          local_favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)
          header_color, header_text_color, header_theme_json = extract_header_colors(feed, local_favicon_path)
          final_header_color, final_text_color = extract_legacy_header_from_theme(header_color, header_text_color, header_theme_json)

          preserved_header_color = final_header_color || previous_data.try(&.header_color)
          preserved_text_color = final_text_color || previous_data.try(&.header_text_color)
          preserved_theme = header_theme_json || previous_data.try(&.header_theme_colors)

          fd = FeedData.new(
            feed.title,
            feed.url,
            site_link,
            preserved_header_color,
            preserved_text_color,
            items,
            result.etag,
            result.last_modified,
            favicon,
            favicon_data
          )

          fd = fd.with_header_theme_colors(preserved_theme) if preserved_theme

          @cache.add(fd)

          if final_result = process_response_result(fd, feed, effective_item_limit, previous_data)
            return final_result
          end
          return fd
        else
          error_msg = result.error_message || "Unknown error"
          HealthMonitor.log_warning("fetch_feed(#{feed.url}) error: #{error_msg}")
          if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
            return stale_cache
          else
            return build_error_feed_data(feed, "Error: #{error_msg}")
          end
        end
      rescue IO::TimeoutError
        HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout after 60s")
        HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Timeout)
        retries = handle_timeout_error(feed, retries)
      rescue ex
        result, retries = handle_fetch_exception(ex, feed, effective_item_limit, previous_data, retries)
        return result if result
      end
    end
  end

  # Load feeds from cache into state store
  def load_from_cache(config : Config) : Bool
    StateStore.update(&.copy_with(config_title: config.page_title, config: config))

    cached_feeds = config.feeds.compact_map { |feed_config| @cache.get(feed_config.url) }

    cached_tabs = config.tabs.map do |tab_config|
      tab_feeds = tab_config.feeds.compact_map { |feed_config| @cache.get(feed_config.url) }
      Tab.new(tab_config.name, tab_feeds, [] of FeedData)
    end

    StateStore.update do |state|
      state.copy_with(
        feeds: cached_feeds,
        tabs: cached_tabs,
        updated_at: Time.local
      )
    end

    if cached_feeds.empty? && cached_tabs.all?(&.feeds.empty?)
      STDERR.puts "[#{Time.local}] load_feeds_from_cache: no cached data found"
      return false
    end

    STDERR.puts "[#{Time.local}] load_feeds_from_cache: loaded #{cached_feeds.size} feeds and #{cached_tabs.size} tabs from cache"
    true
  end

  # Build error feed data for failed fetches
  def build_error_feed_data(feed : Feed, message : String) : FeedData
    site_link = feed.url

    STDERR.puts "[#{Time.local}] [FEED ERROR] #{feed.title} (#{feed.url}) - #{message}"

    favicon, favicon_data = VugAdapter.get_favicon(site_link, nil, nil, nil)

    header_color, header_text_color = extract_header_colors(feed, favicon_data)

    if favicon.nil? && favicon_data.nil?
      favicon = VugAdapter.google_favicon_url(site_link.presence || feed.url)
    end

    FeedData.new(
      feed.title,
      feed.url,
      site_link,
      header_color,
      header_text_color,
      [Item.new(message, feed.url, nil, nil, nil, nil)],
      nil,
      nil,
      favicon,
      favicon_data,
      message
    )
  end

  # Private helper methods

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

  private def handle_success_response(feed : Feed, response : HTTP::Client::Response, display_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData?) : FeedData
    parsed = parse_feed(response.body_io, db_fetch_limit)
    items = parsed[:items]
    site_link = parsed[:site_link] || feed.url

    favicon, favicon_data = VugAdapter.get_favicon(site_link, parsed[:favicon], previous_data.try(&.favicon), previous_data.try(&.favicon_data))

    if favicon.nil? && favicon_data.nil?
      favicon = VugAdapter.google_favicon_url(site_link.presence || feed.url)
    end

    local_favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)
    header_color, header_text_color, header_theme_json = extract_header_colors(feed, local_favicon_path)

    etag = response.headers["ETag"]?
    last_modified = response.headers["Last-Modified"]?

    if items.empty?
      debug_log("Feed returned no items: #{feed.title} (#{feed.url})")
      return build_error_feed_data(feed, "No items found (or unsupported format)")
    end

    final_header_color, final_header_text = extract_legacy_header_from_theme(header_color, header_text_color, header_theme_json)

    fd = FeedData.new(
      feed.title,
      feed.url,
      site_link,
      final_header_color,
      final_header_text,
      items,
      etag,
      last_modified,
      favicon,
      favicon_data
    )

    fd = fd.with_header_theme_colors(header_theme_json) if header_theme_json

    fd
  end

  private def extract_theme_text_value(parsed_text : JSON::Any, current_text : String?) : String?
    return current_text unless current_text.nil? || current_text == ""

    begin
      new_text = (parsed_text.is_a?(Hash) && parsed_text["light"]? ? parsed_text["light"] : parsed_text["dark"]?)
      new_text.to_s if new_text
    rescue ex
      HealthMonitor.log_error("extract_theme_text_value", ex)
      nil
    end
  end

  private def extract_legacy_header_from_theme(header_color : String?, header_text_color : String?, header_theme_json : String?) : {String?, String?}
    return {header_color, header_text_color} unless header_theme_json

    final_header_color = header_color
    final_header_text = header_text_color

    begin
      parsed = JSON.parse(header_theme_json).as_h

      if (parsed_text = parsed["text"]?) && (new_text = extract_theme_text_value(parsed_text, final_header_text))
        final_header_text = new_text
      end

      if (parsed_bg = parsed["bg"]?) && (final_header_color.nil? || final_header_color == "")
        final_header_color = parsed_bg.to_s
      end
    rescue ex
      HealthMonitor.log_error("extract_legacy_header_from_theme(parse)", ex)
    end

    {final_header_color, final_header_text}
  end

  private def parse_theme_text_value(text_val) : Hash(String, String)?
    return unless text_val

    has_text = (text_val.is_a?(Hash) && !text_val.empty?) || (text_val.is_a?(String) && !text_val.empty?)
    return unless has_text

    parsed_text = nil.as(Hash(String, String)?)
    if text_val.is_a?(Hash)
      parsed_text = {} of String => String
      text_val.each do |k, v|
        parsed_text[k.to_s] = v.to_s
      end
    else
      begin
        tmp = JSON.parse(text_val.to_s).as_h
        parsed_text = {} of String => String
        tmp.each do |k, v|
          parsed_text[k.to_s] = v.to_s
        end
      rescue
        parsed_text = {"light" => text_val.to_s, "dark" => text_val.to_s}
      end
    end
    parsed_text
  end

  private def normalize_bg_value(extracted : Hash?) : String?
    return unless extracted && extracted.has_key?("bg")

    raw_bg = extracted["bg"]
    if raw_bg.is_a?(String)
      raw_bg
    elsif raw_bg.is_a?(JSON::Any)
      begin
        raw_bg.as_s
      rescue
        raw_bg.to_s
      end
    else
      raw_bg.to_s
    end
  end

  private def extract_header_colors(feed : Feed, favicon_path : String?) : {String?, String?, String?}
    if favicon_path && favicon_path.starts_with?("/favicons/")
      begin
        extracted = ColorExtractor.theme_aware_extract_from_favicon(favicon_path, feed.url, feed.header_color)

        if extracted && extracted.is_a?(Hash) && extracted.has_key?("text")
          text_val = extracted["text"]

          parsed_text = parse_theme_text_value(text_val)

          if parsed_text
            theme_payload = {
              "bg"     => (extracted.has_key?("bg") ? extracted["bg"] : nil),
              "text"   => parsed_text || {"light" => nil, "dark" => nil},
              "source" => "auto",
            }

            header_theme_json = theme_payload.to_json

            legacy_text = parsed_text["light"]? || parsed_text["dark"]?

            bg_val = normalize_bg_value(extracted)

            return {bg_val, legacy_text, header_theme_json}
          end
        end
      rescue ex
        HealthMonitor.log_error("extract_header_colors(theme-aware)", ex)
      end
    end

    {feed.header_color, feed.header_text_color, nil}
  end

  private def should_abort_fetch?(feed : Feed, elapsed_seconds : Float, retries : Int32, redirects : Int32, timeout_seconds : Int32) : {Bool, String?}
    if elapsed_seconds > timeout_seconds
      return {true, "Error: Fetch timeout after #{timeout_seconds}s (retries: #{retries})"}
    end

    if redirects > Constants::MAX_REDIRECTS
      return {true, "Error: Too many redirects (#{redirects})"}
    end

    if retries >= Constants::MAX_RETRIES
      return {true, "Error: Failed after #{retries} retries"}
    end

    {false, nil}
  end

  private def calculate_backoff(feed : Feed, retries : Int32) : Int32
    Math.min(60, 2 ** retries)
  end

  private def handle_server_error(feed : Feed, retries : Int32, status_code : Int32) : Int32
    new_retries = retries + 1
    backoff_seconds = calculate_backoff(feed, new_retries)
    HealthMonitor.log_warning("fetch_feed(#{feed.url}) server error #{status_code}, retry #{new_retries}/3 in #{backoff_seconds}s")
    sleep(backoff_seconds.seconds)
    new_retries
  end

  private def handle_timeout_error(feed : Feed, retries : Int32) : Int32
    new_retries = retries + 1
    backoff_seconds = calculate_backoff(feed, new_retries)
    HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout, retry #{new_retries}/3 in #{backoff_seconds}s")
    sleep(backoff_seconds.seconds)
    new_retries
  end

  private def handle_feed_response(feed : Feed, response : HTTP::Client::Response, current_url : String, redirects : Int32, display_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData?) : {FeedData?, Int32, Bool, String}
    if response.status.redirection? && (location = response.headers["Location"]?)
      new_url = URI.parse(current_url).resolve(location).to_s

      # Validate redirect URL to prevent SSRF attacks
      unless validate_redirect_url(new_url)
        HealthMonitor.log_warning("fetch_feed(#{feed.url}) blocked redirect to private/internal address: #{new_url}")
        return {nil, redirects, false, current_url}
      end

      return {nil, redirects + 1, false, new_url}
    end

    if response.status_code == 304 && previous_data
      return {previous_data, redirects, true, current_url}
    end

    if response.status.success?
      result = handle_success_response(feed, response, display_limit, db_fetch_limit, previous_data)
      @cache.add(result)
      return {result, redirects, true, current_url}
    end

    if response.status.server_error?
      return {nil, redirects, false, current_url}
    end

    error_result = build_error_feed_data(feed, "Error fetching feed (status #{response.status_code})")
    {error_result, redirects, true, current_url}
  end

  private def get_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    return unless cached = @cache.get(feed.url)
    return unless last_fetched = @cache.get_fetched_time(feed.url)

    return unless cache_fresh?(last_fetched, 5) && cached.items.size >= item_limit

    build_cached_feed_data(cached, previous_data)
  end

  private def get_stale_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    cached = @cache.get(feed.url)
    return unless cached

    build_cached_feed_data(cached, previous_data)
  end

  private def build_cached_feed_data(cached : FeedData, previous_data : FeedData?) : FeedData?
    if previous_data && (prev_favicon_data = previous_data.favicon_data)
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
end

# Global functions for backward compatibility - delegate to singleton

def fetch_feed(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
  if feed.url.includes?("reddit.com/r/")
    return fetch_reddit_feed(feed, display_item_limit)
  end

  FeedFetcher.instance.fetch(feed, display_item_limit, db_fetch_limit, previous_data)
end

private def get_reddit_cached_data(feed : Feed, limit : Int32) : FeedData?
  cache_url = feed.url
  normalized = normalize_url(feed.url)

  cached = FeedCache.instance.get(cache_url) || FeedCache.instance.get(normalized)
  return unless cached

  last_fetched = FeedCache.instance.get_fetched_time(cache_url) || FeedCache.instance.get_fetched_time(normalized)
  return unless last_fetched

  cache_age = (Time.utc - last_fetched).total_minutes
  return unless cache_age < 5 && cached.items.size >= limit

  # Cache is fresh, trigger background fetch and return cached
  spawn fetch_reddit_background(feed, limit)
  cached
end

private def build_reddit_feed_data(feed : Feed, result, items : Array(Item)) : FeedData
  feed_data = FeedData.new(
    feed.title,
    feed.url,
    result.site_link || feed.url,
    feed.header_color,
    feed.header_text_color,
    items,
    result.etag,
    result.last_modified,
    result.favicon,
    nil
  )

  # Store in cache using normalized URL for consistency
  cached_data = FeedData.new(
    feed.title,
    normalize_url(feed.url),
    result.site_link || feed.url,
    feed.header_color,
    feed.header_text_color,
    items,
    result.etag,
    result.last_modified,
    result.favicon,
    nil
  )
  FeedCache.instance.add(cached_data)

  feed_data
end

private def handle_reddit_error(feed : Feed, error : String?) : FeedData
  cached = FeedCache.instance.get(feed.url) || FeedCache.instance.get(normalize_url(feed.url))
  cached || FeedFetcher.instance.build_error_feed_data(feed, error || "Unknown error")
end

private def fetch_reddit_feed(feed : Feed, limit : Int32) : FeedData
  # First try to return cached data if available and fresh
  if cached_data = get_reddit_cached_data(feed, limit)
    return cached_data
  end

  # No fresh cache, fetch new data
  # Use pull_reddit directly to avoid header conflicts
  result = Fetcher.pull_reddit(feed.url, HTTP::Headers.new, limit, fetcher_config)

  if error = result.error_message
    return handle_reddit_error(feed, error)
  end

  items = result.entries.map do |entry|
    comment_url = entry.comment_url || (entry.is_discussion_url ? entry.url : nil)
    Item.new(entry.title, entry.url, entry.published_at, nil, comment_url, entry.commentary_url)
  end

  build_reddit_feed_data(feed, result, items)
rescue ex
  handle_reddit_error(feed, "Error: #{ex.message}")
end

private def fetch_reddit_background(feed : Feed, limit : Int32)
  result = Fetcher.pull_reddit(feed.url, HTTP::Headers.new, limit, fetcher_config)
  return unless result.success?
  return if result.entries.empty?

  items = result.entries.map do |entry|
    comment_url = entry.comment_url || (entry.is_discussion_url ? entry.url : nil)
    Item.new(entry.title, entry.url, entry.published_at, nil, comment_url, entry.commentary_url)
  end

  feed_data = FeedData.new(
    feed.title,
    normalize_url(feed.url),
    result.site_link || feed.url,
    feed.header_color,
    feed.header_text_color,
    items,
    result.etag,
    result.last_modified,
    result.favicon,
    nil
  )

  FeedCache.instance.add(feed_data)
end

private def normalize_url(url : String) : String
  UrlNormalizer.normalize(url)
end

# Validate redirect URL to prevent SSRF attacks
private def validate_redirect_url(url : String) : Bool
  Utils.validate_proxy_host(url)
end

private def fetcher_config : Fetcher::RequestConfig
  config = StateStore.config
  debug_enabled = config.try(&.debug?) || false
  Fetcher::RequestConfig.new(debug_streaming: debug_enabled)
end

def error_feed_data(feed : Feed, message : String) : FeedData
  FeedFetcher.instance.build_error_feed_data(feed, message)
end

def load_feeds_from_cache(config : Config) : Bool
  FeedFetcher.instance.load_from_cache(config)
end
