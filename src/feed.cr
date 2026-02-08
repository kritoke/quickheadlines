require "http/client"
require "uri"
require "./utils"
require "./favicon_storage"
require "./fav"
require "./health_monitor"
require "./color_extractor"

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

        favicon = favicon_urls[0] if favicon.nil?
      end
    rescue
      # ignore
    end
  end
  favicon
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

    # If previous stored data was a data URI, convert it to a saved file and return
    if prev_data.starts_with?("data:image/")
      if converted = convert_cached_data_uri(prev_data, favicon)
        FAVICON_CACHE.set(favicon, converted)
        return converted
      end
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

private def extract_favicon_from_html(site_link : String) : String?
  debug_log("Extracting favicon from HTML: #{site_link}")
  begin
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
            return favicon_url
          end
        end
      end
    end
  rescue
  end
  nil
end

private def extract_header_colors(feed : Feed, favicon_path : String?) : {String?, String?, String?}
  if favicon_path && favicon_path.starts_with?("/favicons/")
    begin
      extracted = ColorExtractor.theme_aware_extract_from_favicon(favicon_path, feed.url, feed.header_color)
      if extracted && extracted.is_a?(Hash) && extracted.has_key?("text")
        text_val = extracted["text"]
        parsed_text = parse_extracted_text_to_parsed_text(text_val)
        has_text = parsed_text && !parsed_text.empty?
        if has_text
          parsed_text_non_nil = parsed_text.not_nil!
          bg_val = normalize_bg_value(extracted)
          header_theme_json = build_header_theme_json(bg_val, parsed_text_non_nil)
          legacy_text = parsed_text_non_nil.has_key?("light") ? parsed_text_non_nil["light"] : parsed_text_non_nil["dark"]
          return {bg_val, legacy_text, header_theme_json}
        end
      end
    rescue ex
      HealthMonitor.log_error("extract_header_colors(theme-aware)", ex)
    end
  end

  {feed.header_color, feed.header_text_color, nil}
end

private def parse_extracted_text_to_parsed_text(text_val) : Hash(String, String)?
  return nil unless text_val
  parsed_text = {} of String => String
  if text_val.is_a?(Hash)
    text_val.each do |k, v|
      parsed_text[k.to_s] = v.to_s
    end
    return parsed_text
  end

  if text_val.is_a?(JSON::Any)
    begin
      tmp = text_val.as_h
      tmp.each do |k, v|
        parsed_text[k.to_s] = v.to_s
      end
      return parsed_text
    rescue
    end
  end

  begin
    tmp = JSON.parse(text_val.to_s).as_h
    tmp.each do |k, v|
      parsed_text[k.to_s] = v.to_s
    end
    parsed_text
  rescue
    {"light" => text_val.to_s, "dark" => text_val.to_s}
  end
end

private def normalize_bg_value(extracted) : String?
  return nil unless extracted.has_key?("bg")
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

private def build_header_theme_json(bg_val : String?, parsed_text : Hash(String, String)?) : String
  theme_payload = {
    "bg"     => bg_val,
    "text"   => parsed_text || {"light" => nil, "dark" => nil},
    "source" => "auto",
  }
  theme_payload.to_json
end

# Try to fetch favicon from HTML as a fallback
# Returns {favicon_url, favicon_data} tuple
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

# Try to fetch favicon from Google service as final fallback
# Returns {favicon_url, favicon_data} tuple
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

private def get_favicon(feed : Feed, site_link : String, parsed_favicon : String?, previous_data : FeedData?) : {String?, String?}
  debug_log("get_favicon: feed=#{feed.url} parsed_favicon=#{parsed_favicon.inspect} site_link=#{site_link}")
  favicon = resolve_favicon(feed, site_link, parsed_favicon)
  debug_log("get_favicon: resolved favicon=#{favicon.inspect}")
  return {favicon, nil} unless favicon
  favicon_data = fetch_favicon_data(favicon, site_link, previous_data)
  debug_log("get_favicon: fetched favicon_data=#{favicon_data.inspect} for favicon=#{favicon}")
  if favicon_data && favicon_data.starts_with?("/favicons/")
    debug_log("get_favicon: using saved favicon path=#{favicon_data}")
    favicon = favicon_data
  end
  {favicon, favicon_data}
end

private def convert_cached_data_uri(data : String, url : String) : String
  if data.starts_with?("data:image/")
    if converted_url = FaviconStorage.convert_data_uri(data, url)
      return converted_url
    end
  end
  data
end

private def parse_feed_parsed(response_io : IO, db_fetch_limit : Int32) : {Array(Item), String?}
  parsed = parse_feed(response_io, db_fetch_limit)
  items = parsed[:items]
  site_link = parsed[:site_link] || nil
  {items, site_link}
end

private def compute_header_values(feed : Feed, site_link : String?, parsed_favicon : String?, previous_data : FeedData?) : {String?, String?, String?, String?, String?}
  # Returns: favicon, favicon_data, header_color, header_text_color, header_theme_json
  favicon, favicon_data = get_favicon(feed, site_link || feed.url, parsed_favicon, previous_data)
  local_favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)
  header_color, header_text_color, header_theme_json = extract_header_colors(feed, local_favicon_path)
  {favicon, favicon_data, header_color, header_text_color, header_theme_json}
end

private def apply_theme_fields(header_theme_json : String?, final_header_color : String?, final_header_text : String?) : {String?, String?}
  return {final_header_color, final_header_text} unless header_theme_json
  begin
    parsed_theme = JSON.parse(header_theme_json).as_h
    if parsed_text = parsed_theme["text"]
      if final_header_text.nil? || final_header_text == ""
        begin
          new_text = extract_text_from_parsed_text(parsed_text)
          final_header_text = new_text.to_s if new_text
        rescue
          # ignore parse errors
        end
      end
    end

    if parsed_bg = parsed_theme["bg"]
      if final_header_color.nil? || final_header_color == ""
        final_header_color = parsed_bg.to_s
      end
    end
  rescue
    # ignore parse errors
  end
  {final_header_color, final_header_text}
end

private def extract_text_from_parsed_text(parsed_text)
  if parsed_text.is_a?(Hash)
    return parsed_text["light"]? || parsed_text["dark"]?
  end
  parsed_text.to_s
end

private def handle_fetch_exception(ex : Exception, feed : Feed, retries : Int32) : {Int32, FeedData?}
  error_msg = ex.message
  is_timeout = ex.is_a?(IO::TimeoutError) || (error_msg.is_a?(String) && error_msg.downcase.includes?("timeout"))
  if is_timeout
    HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout: #{error_msg}")
    HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Timeout)
    return { handle_timeout_error(feed, retries), nil }
  else
    HealthMonitor.log_error("fetch_feed(#{feed.url})", ex)
    HealthMonitor.update_feed_health(feed.url, FeedHealthStatus::Unreachable)
    return { retries, error_feed_data(feed, "Error: #{ex.class} - #{error_msg}") }
  end
end

private def merge_legacy_header_fields(header_color : String?, header_text_color : String?, header_theme_json : String?) : {String?, String?}
  final_header_color = header_color
  final_header_text = header_text_color
  apply_theme_fields(header_theme_json, final_header_color, final_header_text)
end

private def perform_request_and_handle(feed : Feed, current_url : String, effective_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData?, cache : FeedCache, redirects : Int32) : {FeedData?, Int32, Bool, String, Bool}
  uri = URI.parse(current_url)
  client = create_client(current_url)
  headers = build_fetch_headers(feed, current_url, previous_data)

  result = nil
  new_redirects = redirects
  should_return = false
  new_url = current_url
  server_error = false

  client.get(uri.request_target, headers: headers) do |response|
    result, new_redirects, should_return, new_url = handle_feed_response(
      feed, response, current_url, redirects, effective_item_limit, db_fetch_limit, previous_data, cache
    )
    if response.status.server_error?
      server_error = true
    end
  end

  {result, new_redirects, should_return, new_url, server_error}
end

private def handle_success_response(feed : Feed, response : HTTP::Client::Response, display_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData?) : FeedData
  items, site_link = parse_feed_parsed(response.body_io, db_fetch_limit)

  favicon, favicon_data, header_color, header_text_color, header_theme_json = compute_header_values(feed, site_link, nil, previous_data)

  etag = response.headers["ETag"]?
  last_modified = response.headers["Last-Modified"]?

  if items.empty?
    items = [Item.new("No items found (or unsupported format)", feed.url, nil)]
  end

  final_header_color, final_header_text = merge_legacy_header_fields(header_color, header_text_color, header_theme_json)

  fd = FeedData.new(
    feed.title,
    feed.url,
    site_link || feed.url,
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

private def error_feed_data(feed : Feed, message : String) : FeedData
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

private def check_and_handle_abort(feed : Feed, start_time : Time::Span, retries : Int32, redirects : Int32, timeout_seconds : Int32) : FeedData?
  elapsed_seconds = (Time.monotonic - start_time).total_seconds
  abort_msg = should_abort_fetch?(feed, elapsed_seconds, retries, redirects, timeout_seconds)
  if abort_msg[0]
    message = abort_msg[1] || "Error: Unknown fetch error"
    HealthMonitor.log_warning("fetch_feed(#{feed.url}) #{message}")
    return error_feed_data(feed, message)
  end
  nil
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
    if early = check_and_handle_abort(feed, start_time, retries, redirects, timeout_seconds)
      return early
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
      new_retries, maybe_feeddata = handle_fetch_exception(ex, feed, retries)
      retries = new_retries
      if maybe_feeddata
        return maybe_feeddata
      end
    end
  end
end

def refresh_all(config : Config)
  STATE.config_title = config.page_title
  STATE.config = config
  all_configs = {} of String => Feed
  config.feeds.each { |feed| all_configs[feed.url] = feed }
  config.tabs.each { |tab| tab.feeds.each { |feed| all_configs[feed.url] = feed } }
  STDERR.puts "[#{Time.local}] refresh_all: starting - #{all_configs.size} feeds to fetch"
  existing_data = (STATE.feeds + STATE.tabs.flat_map(&.feeds)).index_by(&.url)
  STDERR.puts "[#{Time.local}] refresh_all: existing_data.size=#{existing_data.size}"
  channel = Channel(FeedData).new
  all_configs.each_value do |feed|
    spawn do
      SEM.receive
      begin
        prev = existing_data[feed.url]?
        channel.send(fetch_feed(feed, config.item_limit, config.db_fetch_limit, prev))
      ensure
        SEM.send(nil)
      end
    end
  end

  fetched_map = {} of String => FeedData
  all_configs.size.times do
    data = channel.receive
    if data && !data.items.empty?
      fetched_map[data.url] = data
    else
      STDERR.puts "[#{Time.local}] refresh_all: failed to fetch #{data ? data.url : "unknown"}"
    end
  end

  STDERR.puts "[#{Time.local}] refresh_all: fetched #{fetched_map.size}/#{all_configs.size} feeds successfully"
  STDERR.puts "[#{Time.local}] refresh_all: clearing STATE (feeds=#{STATE.feeds.size}, tabs=#{STATE.tabs.size})"
  STATE.feeds.clear
  STATE.tabs.each &.feeds.clear
  STATE.software_releases.clear
  STATE.feeds = config.feeds.map { |feed| fetched_map[feed.url] || error_feed_data(feed, "Failed to fetch") }
  STDERR.puts "[#{Time.local}] refresh_all: STATE.feeds=#{STATE.feeds.size}"
  STATE.software_releases = [] of FeedData
  if sw = config.software_releases
    if sw_box = fetch_sw_with_config(sw, config.item_limit)
      STATE.software_releases << sw_box
    end
  end
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
  GC.collect
  STDERR.puts "[#{Time.local}] refresh_all: complete - STATE.feeds=#{STATE.feeds.size}, STATE.tabs=#{STATE.tabs.size}"
end

def start_refresh_loop(config_path : String)
  active_config = load_config(config_path)
  last_mtime = File.info(config_path).modification_time
  refresh_all(active_config)
  puts "[#{Time.local}] Initial refresh complete"
  save_feed_cache(FeedCache.instance, active_config.cache_retention_hours, active_config.max_cache_size_mb)
  spawn do
    loop do
      refresh_start_time = Time.monotonic
      begin
        current_mtime = File.info(config_path).modification_time
        if current_mtime > last_mtime
          new_config = load_config(config_path)
          active_config = new_config
          last_mtime = current_mtime
          puts "[#{Time.local}] Config change detected. Reloaded feeds.yml"
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed after config change"
        else
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed feeds and ran GC"
        end
        save_feed_cache(FeedCache.instance, active_config.cache_retention_hours, active_config.max_cache_size_mb)
        refresh_duration = (Time.monotonic - refresh_start_time).total_seconds
        if refresh_duration > (active_config.refresh_minutes * 60) * 2
          HealthMonitor.log_warning("Refresh took #{refresh_duration.round(2)}s (expected #{active_config.refresh_minutes * 60}s) - possible hang detected")
        end
        sleep (active_config.refresh_minutes * 60).seconds
      rescue ex
        HealthMonitor.log_error("refresh_loop", ex)
        sleep 1.minute
      end
    end
  end
end
