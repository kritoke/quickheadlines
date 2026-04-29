require "base64"
require "time"
require "json"
require "fetcher"
require "../config"
require "../constants"
require "../models"
require "../storage"
require "../color_extractor"
require "./vug_adapter"
require "./theme_helper"
require "./software_util"

# FeedFetcher encapsulates all feed fetching logic with proper dependency injection.
# Use FeedFetcher.instance for singleton access after AppBootstrap initializes it.
class FeedFetcher
  include Fetcher::ThemeHelper

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

  # Singleton accessor
  @@instance : FeedFetcher?
  @@instance_mutex = Mutex.new

  def self.instance : FeedFetcher
    @@instance_mutex.synchronize { @@instance.not_nil! }
  end

  def self.instance=(fetcher : FeedFetcher)
    @@instance_mutex.synchronize { @@instance = fetcher }
  end

  private def stale_cache_fallback?(result : FeedData, feed : Feed) : Bool
    result.items.size >= 1 &&
      (first_item = result.items.first) &&
      first_item.title.starts_with?("Error:") &&
      first_item.link == feed.url
  end

  private def handle_fetch_exception(ex : Exception, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, retries : Int32) : FetchErrorResult
    error_msg = ex.message
    is_timeout = error_msg.is_a?(String) && error_msg.downcase.includes?("timeout")

    if is_timeout
      Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) timeout: #{error_msg}" }
      FetchErrorResult.new(nil, handle_timeout_error(feed, retries))
    else
      Log.for("quickheadlines.feed").error(exception: ex) { "fetch_feed(#{feed.url})" }
      if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
        FetchErrorResult.new(stale_cache, retries)
      else
        FetchErrorResult.new(build_error_feed(feed, "Error: #{ex.class} - #{error_msg}"), retries)
      end
    end
  end

  private def handle_abort_condition(feed : Feed, effective_item_limit : Int32, previous_data : FeedData?, decision : FetchAbortDecision) : FeedData?
    return unless decision.abort?

    message = decision.reason || "Error: Unknown fetch error"
    Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) #{message}" }
    if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
      stale_cache
    else
      build_error_feed(feed, message)
    end
  end

  private def process_response_result(result_data : FeedData, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?) : FeedData?
    if stale_cache_fallback?(result_data, feed)
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
        result = Fetcher.pull(current_url, HTTP::Headers.new, db_fetch_limit, FeedFetcher.fetcher_config)

        if result.success?
          return handle_success(result, feed, effective_item_limit, previous_data)
        else
          return handle_error(result, feed, effective_item_limit, previous_data)
        end
      rescue IO::TimeoutError
        Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) timeout after 60s" }
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

  private def handle_success(result, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?) : FeedData
    items = entries_to_items(result.entries)

    if items.empty?
      debug_log("Feed returned no items: #{feed.title} (#{feed.url})")
      return build_error_feed(feed, "No items found (or unsupported format)")
    end

    site_link = result.site_link || feed.url
    favicon, favicon_data = resolve_favicons(site_link, feed, result.favicon, previous_data)

    local_favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)
    header_color, header_text_color, header_theme_json = extract_header_colors(feed, local_favicon_path)
    final_header_color, final_text_color = parse_legacy_theme(header_color, header_text_color, header_theme_json)

    preserved_header_color = final_header_color || previous_data.try(&.header_color)
    preserved_text_color = final_text_color || previous_data.try(&.header_text_color)
    preserved_theme = header_theme_json || previous_data.try(&.header_theme_colors)

    feed_data = FeedData.new(
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

    feed_data = feed_data.with_theme_colors(preserved_theme) if preserved_theme

    store_content_from_items(feed_data)

    @cache.add(feed_data)

    if final_result = process_response_result(feed_data, feed, effective_item_limit, previous_data)
      return final_result
    end
    feed_data
  end

  private def resolve_favicons(site_link : String, feed : Feed, result_favicon, previous_data : FeedData?) : Tuple(String?, String?)
    favicon, favicon_data = safe_get_favicon_with_fallback(site_link, result_favicon, previous_data.try(&.favicon), previous_data.try(&.favicon_data))

    if favicon.nil? && favicon_data.nil?
      domain = extract_domain_for_favicon(site_link, feed.url)
      if domain
        google_url = VugAdapter.google_favicon_url(domain)
        if saved = FaviconStorage.fetch_and_save(google_url)
          favicon = saved
          favicon_data = saved
        end
      end
    end

    {favicon, favicon_data}
  end

  private def extract_domain_for_favicon(site_link : String, feed_url : String) : String?
    if site_link && !site_link.starts_with?("#") && !site_link.includes?("#") && !site_link.starts_with?("placeholder:") && site_link.presence
      uri = URI.parse(site_link)
      return uri.host if uri.host
    end
    uri = URI.parse(feed_url)
    uri.host
  end

  private def handle_error(result, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?) : FeedData
    error_msg = result.error_message || "Unknown error"
    Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) error: #{error_msg}" }
    if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
      return stale_cache
    end
    build_error_feed(feed, "Error: #{error_msg}")
  end

  # Load feeds from cache into state store
  def load_from_cache(config : Config, item_limit : Int32 = config.item_limit) : Bool
    StateStore.update(&.copy_with(config_title: config.page_title, config: config))

    all_feed_urls = config.all_feed_urls
    all_cached_feeds = all_feed_urls.compact_map { |url| @cache.get(url) }

    cached_tabs = config.tabs.map do |tab_config|
      tab_feeds = tab_config.feeds.compact_map { |feed_config| @cache.get(feed_config.url) }
      tab_releases = build_software_releases(tab_config.software_releases, item_limit)
      Tab.new(tab_config.name, tab_feeds, tab_releases)
    end

    StateStore.update do |state|
      state.copy_with(
        feeds: all_cached_feeds,
        tabs: cached_tabs,
        updated_at: Time.utc
      )
    end

    if all_cached_feeds.empty? && cached_tabs.all?(&.feeds.empty?)
      Log.for("quickheadlines.feed").debug { "load_feeds_from_cache: no cached data found" }
      return false
    end

    Log.for("quickheadlines.feed").debug { "load_feeds_from_cache: loaded #{all_cached_feeds.size} feeds and #{cached_tabs.size} tabs from cache" }
    true
  end

  private def build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
    QuickHeadlines::SoftwareUtil.build_software_releases(software_config, item_limit)
  end

  # Build error feed data for failed fetches
  # NOTE: We skip VugAdapter favicon fetching here because:
  # 1. Error feeds don't need favicons - they display an error state
  # 2. VugAdapter calls can hang on DNS revalidation failures, blocking the server
  # 3. We already fallback to Google favicon URL below if no cached favicon exists
  def build_error_feed(feed : Feed, message : String) : FeedData
    site_link = feed.url

    Log.for("quickheadlines.feed").warn { "[FEED ERROR] #{feed.title} (#{feed.url}) - #{message}" }

    # Skip VugAdapter for error feeds - use Google favicon directly as fallback
    favicon = VugAdapter.google_favicon_url(site_link.presence || feed.url)
    favicon_data = nil

    header_color, header_text_color = extract_header_colors(feed, favicon_data)

    FeedData.new(
      title: feed.title,
      url: feed.url,
      site_link: site_link,
      header_color: header_color,
      header_text_color: header_text_color,
      items: [Item.new(message, feed.url, nil, nil, nil, nil)],
      etag: nil,
      last_modified: nil,
      favicon: favicon,
      favicon_data: favicon_data,
      error_message: message,
      header_theme_colors: nil,
    )
  end

  private def safe_get_favicon(site_link : String) : {String?, String?}
    safe_get_favicon_with_fallback(site_link, nil, nil, nil)
  end

  private def safe_get_favicon_with_fallback(site_link : String, parsed_favicon : String?, prev_favicon : String?, prev_favicon_data : String?) : {String?, String?}
    favicon, favicon_data = nil, nil
    begin
      favicon, favicon_data = VugAdapter.get_favicon(site_link, parsed_favicon, prev_favicon, prev_favicon_data)
    rescue ex : IO::TimeoutError | Socket::Addrinfo::Error
      Log.for("quickheadlines.feed").debug { "VugAdapter.get_favicon failed for #{site_link}: #{ex.class}" }
    rescue ex
      Log.for("quickheadlines.feed").warn { "VugAdapter.get_favicon unexpected error for #{site_link}: #{ex.class} - #{ex.message}" }
    end
    {favicon, favicon_data}
  end

  # Private helper methods

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
    Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) timeout, retry #{new_retries}/#{QuickHeadlines::Constants::MAX_RETRIES} in #{backoff_seconds}s" }
    sleep(backoff_seconds.seconds)
    new_retries
  end

  private def get_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    return unless cached = @cache.get(feed.url)
    return unless last_fetched = @cache.get_fetched_time(feed.url)

    return unless QuickHeadlines::CacheUtils.cache_fresh?(last_fetched, QuickHeadlines::Constants::CACHE_FRESHNESS_MINUTES) && cached.items.size >= item_limit

    build_cached_feed(cached, previous_data)
  end

  private def entries_to_items(entries : Array(Fetcher::Entry)) : Array(Item)
    entries.map do |entry|
      comment_url = entry.comment_url || (entry.is_discussion_url ? entry.url : nil)
      Item.new(entry.title, entry.url, entry.published_at, entry.content, comment_url, entry.commentary_url)
    end.sort_by! { |item| item.pub_date || Time.unix(0) }.reverse!
  end

  private def store_content_from_items(feed_data : FeedData)
    return unless feed_data.items.any?(&.content)
    begin
      content_service = QuickHeadlines::Services::ContentService.instance
    rescue
      return
    end

    feed_data.items.each do |item|
      if content = item.content
        content_service.store_content(item.link, feed_data.url, item.title, content)
      end
    end
  rescue ex
    Log.for("quickheadlines.feed").debug { "Content storage skipped: #{ex.message}" }
  end

  private def get_stale_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    cached = @cache.get(feed.url)
    return unless cached

    build_cached_feed(cached, previous_data)
  end

  private def build_cached_feed(cached : FeedData, previous_data : FeedData?) : FeedData?
    if previous_data && (prev_favicon_data = previous_data.favicon_data)
      favicon_path = FaviconStorage.disk_path(prev_favicon_data)
      if favicon_path && File.exists?(favicon_path)
        favicon = prev_favicon_data.starts_with?("/favicons/") ? prev_favicon_data : cached.favicon
        return FeedData.new(
          title: cached.title,
          url: cached.url,
          site_link: cached.site_link,
          header_color: cached.header_color,
          header_text_color: cached.header_text_color,
          items: cached.items,
          etag: cached.etag,
          last_modified: cached.last_modified,
          favicon: favicon,
          favicon_data: prev_favicon_data,
          header_theme_colors: cached.header_theme_colors,
        )
      end
    end

    cached_favicon = cached.favicon_data
    if cached_favicon.is_a?(String) && cached_favicon.starts_with?("/favicons/")
      favicon_path = FaviconStorage.disk_path(cached_favicon)
      unless favicon_path && File.exists?(favicon_path)
        return FeedData.new(
          title: cached.title,
          url: cached.url,
          site_link: cached.site_link,
          header_color: cached.header_color,
          header_text_color: cached.header_text_color,
          items: cached.items,
          etag: cached.etag,
          last_modified: cached.last_modified,
          favicon: cached.favicon,
          favicon_data: nil,
          header_theme_colors: cached.header_theme_colors,
        )
      end
    end

    cached
  end

  def self.fetcher_config : Fetcher::RequestConfig
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

  def self.load_feeds_from_cache(config : Config) : Bool
    instance.load_from_cache(config)
  end
end
