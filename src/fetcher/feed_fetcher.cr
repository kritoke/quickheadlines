require "athena"
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
@[ADI::Register]
class FeedFetcher
  private record FetchAbortDecision,
    should_abort : Bool,
    reason : String? do
    def abort? : Bool
      should_abort
    end
  end

  private record FetchErrorResult,
    data : FeedData?,
    retries : Int32

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

  private def handle_fetch_exception(ex : Exception, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, retries : Int32) : FetchErrorResult
    error_msg = ex.message
    is_timeout = error_msg.is_a?(String) && error_msg.downcase.includes?("timeout")

    if is_timeout
      HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout: #{error_msg}")
      FetchErrorResult.new(nil, handle_timeout_error(feed, retries))
    else
      HealthMonitor.log_error("fetch_feed(#{feed.url})", ex)
      if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
        FetchErrorResult.new(stale_cache, retries)
      else
        FetchErrorResult.new(build_error_feed_data(feed, "Error: #{ex.class} - #{error_msg}"), retries)
      end
    end
  end

  private def handle_abort_condition(feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, decision : FetchAbortDecision) : FeedData?
    return unless decision.abort?

    message = decision.reason || "Error: Unknown fetch error"
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
      timeout_seconds = QuickHeadlines::Constants::FETCH_TIMEOUT_SECONDS
      elapsed_seconds = (Time.monotonic - start_time).total_seconds
      abort_decision = should_abort_fetch?(feed, elapsed_seconds, retries, redirects, timeout_seconds)

      if abort_result = handle_abort_condition(feed, effective_item_limit, previous_data, abort_decision)
        return abort_result
      end

      begin
        result = Fetcher.pull(current_url, HTTP::Headers.new, db_fetch_limit, fetcher_config)

        if result.success?
          items = entries_to_items(result.entries)

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
        retries = handle_timeout_error(feed, retries)
      rescue ex
        error_result = handle_fetch_exception(ex, feed, effective_item_limit, previous_data, retries)
        retries = error_result.retries
        if data = error_result.data
          return data
        end
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
      Log.for("quickheadlines.feed").debug { "load_feeds_from_cache: no cached data found" }
      return false
    end

    Log.for("quickheadlines.feed").debug { "load_feeds_from_cache: loaded #{cached_feeds.size} feeds and #{cached_tabs.size} tabs from cache" }
    true
  end

  # Build error feed data for failed fetches
  def build_error_feed_data(feed : Feed, message : String) : FeedData
    site_link = feed.url

    Log.for("quickheadlines.feed").warn { "[FEED ERROR] #{feed.title} (#{feed.url}) - #{message}" }

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
      rescue ex : JSON::ParseException | TypeCastError
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
      rescue ex : TypeCastError
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

  private def should_abort_fetch?(feed : Feed, elapsed_seconds : Float, retries : Int32, redirects : Int32, timeout_seconds : Int32) : FetchAbortDecision
    if elapsed_seconds > timeout_seconds
      return FetchAbortDecision.new(true, "Error: Fetch timeout after #{timeout_seconds}s (retries: #{retries})")
    end

    if redirects > QuickHeadlines::Constants::MAX_REDIRECTS
      return FetchAbortDecision.new(true, "Error: Too many redirects (#{redirects})")
    end

    if retries >= QuickHeadlines::Constants::MAX_RETRIES
      return FetchAbortDecision.new(true, "Error: Failed after #{retries} retries")
    end

    FetchAbortDecision.new(false, nil)
  end

  private def calculate_backoff(feed : Feed, retries : Int32) : Int32
    Math.min(QuickHeadlines::Constants::MAX_BACKOFF_SECONDS, 2 ** retries)
  end

  private def handle_timeout_error(feed : Feed, retries : Int32) : Int32
    new_retries = retries + 1
    backoff_seconds = calculate_backoff(feed, new_retries)
    HealthMonitor.log_warning("fetch_feed(#{feed.url}) timeout, retry #{new_retries}/3 in #{backoff_seconds}s")
    sleep(backoff_seconds.seconds)
    new_retries
  end

  private def get_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    return unless cached = @cache.get(feed.url)
    return unless last_fetched = @cache.get_fetched_time(feed.url)

    return unless QuickHeadlines::CacheUtils.cache_fresh?(last_fetched, QuickHeadlines::Constants::CACHE_FRESHNESS_MINUTES) && cached.items.size >= item_limit

    build_cached_feed_data(cached, previous_data)
  end

  private def entries_to_items(entries : Array(Fetcher::Entry)) : Array(Item)
    entries.map do |entry|
      comment_url = entry.comment_url || (entry.is_discussion_url ? entry.url : nil)
      Item.new(entry.title, entry.url, entry.published_at, nil, comment_url, entry.commentary_url)
    end
  end

  private def get_stale_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    cached = @cache.get(feed.url)
    return unless cached

    build_cached_feed_data(cached, previous_data)
  end

  private def build_cached_feed_data(cached : FeedData, previous_data : FeedData?) : FeedData?
    if previous_data && (prev_favicon_data = previous_data.favicon_data)
      favicon_path = FaviconStorage.favicon_dir + prev_favicon_data
      if File.exists?(favicon_path)
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
    end

    cached_favicon = cached.favicon_data
    if cached_favicon.is_a?(String) && cached_favicon.starts_with?("/favicons/")
      favicon_path = FaviconStorage.favicon_dir + cached_favicon
      unless File.exists?(favicon_path)
        return FeedData.new(
          cached.title,
          cached.url,
          cached.site_link,
          cached.header_color,
          cached.header_text_color,
          cached.items,
          cached.etag,
          cached.last_modified,
          cached.favicon,
          nil
        )
      end
    end

    cached
  end
end

# Global functions for backward compatibility - delegate to singleton

def fetch_feed(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
  FeedFetcher.instance.fetch(feed, display_item_limit, db_fetch_limit, previous_data)
end

private def fetcher_config : Fetcher::RequestConfig
  config = StateStore.config
  debug_enabled = config.try(&.debug?) || false
  Fetcher::RequestConfig.new(
    timeout: Fetcher::TimeoutConfig.new(
      connect: QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds,
      read: QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
    ),
    retry: Fetcher::RetryConfig.new(
      max_retries: QuickHeadlines::Constants::MAX_RETRIES
    ),
    max_redirects: QuickHeadlines::Constants::MAX_REDIRECTS,
    streaming: Fetcher::StreamingConfig.new(
      enabled: debug_enabled,
      debug: debug_enabled
    )
  )
end

def error_feed_data(feed : Feed, message : String) : FeedData
  FeedFetcher.instance.build_error_feed_data(feed, message)
end

def load_feeds_from_cache(config : Config) : Bool
  FeedFetcher.instance.load_from_cache(config)
end
