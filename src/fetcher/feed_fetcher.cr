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
require "./fetcher_cache"
require "./fetcher_favicon"
require "./fetcher_response"
require "./fetcher_retry"

# FeedFetcher is the main coordinator for feed fetching.
# It delegates to focused modules:
#   - FetcherCache: cache lookups and stale fallback
#   - FetcherFavicon: favicon resolution with fallbacks
#   - FetcherResponse: success/error handling, content storage
#   - FetcherRetry: retry logic, abort decisions, backoff
class FeedFetcher
  include FetcherCache
  include FetcherFavicon
  include FetcherResponse
  include FetcherRetry

  @cache : FeedCache

  def initialize(@cache : FeedCache)
  end

  # Expose cache to included modules
  protected def cache : FeedCache
    @cache
  end

  # Singleton accessor
  def_singleton_manual("FeedFetcher not initialized. Call FeedFetcher.instance=(fetcher) first.")

  # Main entry point — fetch a feed with caching and retry logic.
  # Timeout control is handled at the caller level (fetch_single_feed_with_timeout).
  def fetch(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
    effective_item_limit = feed.item_limit || display_item_limit

    if cached_data = get_cached_feed(feed, effective_item_limit, previous_data)
      return cached_data
    end

    do_fetch_with_retry(feed, effective_item_limit, db_fetch_limit, previous_data)
  end

  private def do_fetch_with_retry(feed : Feed, effective_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData?) : FeedData
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
        Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) timeout after #{QuickHeadlines::Constants::HTTP_READ_TIMEOUT}s" }
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
  def load_from_cache(config : Config, item_limit : Int32 = config.item_limit) : Bool
    StateStore.update(&.copy_with(config_title: config.page_title, config: config))

    all_feed_urls = config.all_feed_urls
    all_cached_feeds = all_feed_urls.compact_map { |url| @cache.get(url) }

    cached_tabs = config.tabs.map do |tab_config|
      tab_feeds = tab_config.feeds.compact_map { |feed_config| @cache.get(feed_config.url) }
      tab_releases = build_software_releases(tab_config.software_releases, item_limit)
      Tab.new(tab_config.name, tab_feeds, tab_releases)
    end

    Log.for("quickheadlines.feed").info { "load_feeds_from_cache: found cached_feeds=#{all_cached_feeds.size}, cached_tabs=#{cached_tabs.size}; updating StateStore" }

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
