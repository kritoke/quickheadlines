require "base64"
require "time"
require "json"
require "../config"
require "../models"
require "../storage"
require "../health_monitor"
require "../color_extractor"
require "./favicon"

private def build_fetch_headers(feed : Feed, current_url : String, previous_data : FeedData?) : HTTP::Headers
  headers = HTTP::Headers{
    "User-Agent"      => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept"          => "application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.7",
    "Accept-Language" => "en-US,en;q=0.9",
    "Connection"      => "keep-alive",
  }

  if auth = feed.auth
    apply_auth_headers(headers, auth)
  end

  if previous_data && current_url == feed.url
    previous_data.etag.try { |v| headers["If-None-Match"] = v }
    previous_data.last_modified.try { |v| headers["If-Modified-Since"] = v }
  end

  headers
end

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

private def handle_success_response(feed : Feed, response : HTTP::Client::Response, display_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData?) : FeedData
  parsed = parse_feed(response.body_io, db_fetch_limit)
  items = parsed[:items]
  site_link = parsed[:site_link] || feed.url

  favicon, favicon_data = get_favicon(feed, site_link, parsed[:favicon], previous_data)

  local_favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)
  header_color, header_text_color, header_theme_json = extract_header_colors(feed, local_favicon_path)

  etag = response.headers["ETag"]?
  last_modified = response.headers["Last-Modified"]?

  if items.empty?
    items = [Item.new("No items found (or unsupported format)", feed.url, nil)]
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

  fd.header_theme_colors = header_theme_json if header_theme_json

  fd
end

private def extract_legacy_header_from_theme(header_color : String?, header_text_color : String?, header_theme_json : String?) : {String?, String?}
  final_header_color = header_color
  final_header_text = header_text_color

  return {final_header_color, final_header_text} unless header_theme_json

  begin
    parsed = JSON.parse(header_theme_json).as_h
    if parsed_text = parsed["text"]
      if final_header_text.nil? || final_header_text == ""
        begin
          new_text = (parsed_text.is_a?(Hash) && parsed_text["light"] ? parsed_text["light"] : parsed_text["dark"])
          final_header_text = new_text.to_s if new_text
        rescue
        end
      end
    end

    if parsed_bg = parsed["bg"]
      if final_header_color.nil? || final_header_color == ""
        final_header_color = parsed_bg.to_s
      end
    end
  rescue
  end

  {final_header_color, final_header_text}
end

private def parse_theme_text_value(text_val) : Hash(String, String)?
  return nil unless text_val

  has_text = (text_val.is_a?(Hash) && !text_val.empty?) || (text_val.is_a?(String) && !text_val.empty?)
  return nil unless has_text

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
  return nil unless extracted && extracted.has_key?("bg")

  raw_bg = extracted["bg"]
  bg_val = nil.as(String?)
  if raw_bg.is_a?(String)
    bg_val = raw_bg
  elsif raw_bg.is_a?(JSON::Any)
    begin
      bg_val = raw_bg.as_s
    rescue
      bg_val = raw_bg.to_s
    end
  else
    bg_val = raw_bg.to_s
  end
  bg_val
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

def error_feed_data(feed : Feed, message : String) : FeedData
  site_link = feed.url

  favicon, favicon_data = get_favicon(feed, site_link, nil, nil)

  header_color, header_text_color = extract_header_colors(feed, favicon_data)

  if favicon.nil? && favicon_data.nil?
    favicon = FaviconHelper.google_favicon_url(site_link, feed.url)
  end

  FeedData.new(
    feed.title,
    feed.url,
    site_link,
    header_color,
    header_text_color,
    [Item.new(message, feed.url, nil)],
    nil,
    nil,
    favicon,
    favicon_data
  )
end

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

private def calculate_backoff(feed : Feed, retries : Int32) : Int32
  feed.retry_delay * retries
end

private def handle_server_error(feed : Feed, retries : Int32, status_code : Int32) : Int32
  new_retries = retries + 1
  backoff_seconds = calculate_backoff(feed, new_retries)
  HealthMonitor.log_warning("fetch_feed(#{feed.url}) server error #{status_code}, retry #{new_retries}/#{feed.max_retries} in #{backoff_seconds}s")
  sleep(backoff_seconds.seconds)
  new_retries
end

private def handle_timeout_error(feed : Feed, retries : Int32) : Int32
  new_retries = retries + 1
  backoff_seconds = calculate_backoff(feed, new_retries)
  HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout, retry #{new_retries}/#{feed.max_retries} in #{backoff_seconds}s")
  sleep(backoff_seconds.seconds)
  new_retries
end

private def handle_feed_response(feed : Feed, response : HTTP::Client::Response, current_url : String, redirects : Int32, display_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData?, cache : FeedCache) : {FeedData?, Int32, Bool, String}
  if response.status.redirection? && (location = response.headers["Location"]?)
    new_url = URI.parse(current_url).resolve(location).to_s
    return {nil, redirects + 1, false, new_url}
  end

  if response.status_code == 304 && previous_data
    return {previous_data, redirects, true, current_url}
  end

  if response.status.success?
    result = handle_success_response(feed, response, display_limit, db_fetch_limit, previous_data)
    cache.add(result)
    return {result, redirects, true, current_url}
  end

  if response.status.server_error?
    return {nil, redirects, false, current_url}
  end

  error_result = error_feed_data(feed, "Error fetching feed (status #{response.status_code})")
  {error_result, redirects, true, current_url}
end

def fetch_feed(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
  effective_item_limit = feed.item_limit || display_item_limit

  if cached_data = get_cached_feed(feed, effective_item_limit, previous_data)
    return cached_data
  end

  cache = FeedCache.instance
  current_url = feed.url
  redirects = 0
  retries = 0
  start_time = Time.monotonic

  loop do
    timeout_seconds = feed.timeout > 0 ? feed.timeout : 60

    elapsed_seconds = (Time.monotonic - start_time).total_seconds
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
          feed, response, current_url, redirects, effective_item_limit, db_fetch_limit, previous_data, cache
        )
        current_url = new_url

        if should_return
          return result.as(FeedData)
        end

        redirects = new_redirects

        if response.status.server_error?
          retries = handle_server_error(feed, retries, response.status_code)
        end
      end
    rescue ex : IO::TimeoutError
      HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout after #{feed.timeout}s")
      HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Timeout)

      retries = handle_timeout_error(feed, retries)
    rescue ex
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

private def get_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
  cache = FeedCache.instance
  return unless cached = cache.get(feed.url)
  return unless last_fetched = cache.get_fetched_time(feed.url)

  return unless cache_fresh?(last_fetched, 5) && cached.items.size >= item_limit

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

def load_feeds_from_cache(config : Config) : Bool
  cache = FeedCache.instance
  STATE.config_title = config.page_title
  STATE.config = config

  cached_feeds = [] of FeedData
  config.feeds.each do |feed_config|
    if cached = cache.get(feed_config.url)
      cached_feeds << cached
    end
  end

  STATE.with_lock do
    STATE.feeds = cached_feeds
    STATE.tabs = config.tabs.map do |tab_config|
      tab = Tab.new(tab_config.name)
      tab.feeds = tab_config.feeds.compact_map { |feed_config| cache.get(feed_config.url) }
      tab
    end
    STATE.updated_at = Time.local
  end

  if cached_feeds.empty? && STATE.tabs.all?(&.feeds.empty?)
    STDERR.puts "[#{Time.local}] load_feeds_from_cache: no cached data found"
    return false
  end

  STDERR.puts "[#{Time.local}] load_feeds_from_cache: loaded #{cached_feeds.size} feeds and #{STATE.tabs.size} tabs from cache"
  true
end
