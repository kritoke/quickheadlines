require "time"
require "../storage"

# Cache lookup and stale-feed fallback logic extracted from FeedFetcher.
module FetcherCache
  # Check if a cached feed is still fresh and has enough items.
  def get_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    return unless cached = cache.get(feed.url)
    return unless last_fetched = cache.get_fetched_time(feed.url)

    return unless QuickHeadlines::CacheUtils.cache_fresh?(last_fetched, QuickHeadlines::Constants::CACHE_FRESHNESS_MINUTES) && cached.items.size >= item_limit

    build_cached_feed(cached, previous_data)
  end

  # Get a stale cached feed as fallback when fetch fails.
  def get_stale_cached_feed(feed : Feed, item_limit : Int32, previous_data : FeedData?) : FeedData?
    cached = cache.get(feed.url)
    return unless cached

    build_cached_feed(cached, previous_data)
  end

  # Check if a cached result is actually an error feed that should be treated as stale.
  def stale_cache_fallback?(result : FeedData, feed : Feed) : Bool
    result.failed? && result.items.any? { |item| item.link == feed.url }
  end

  # Build a cached feed with favicon path validation.
  # Checks that on-disk favicon files exist; falls back to URL-only favicon if missing.
  private def build_cached_feed(cached : FeedData, previous_data : FeedData?) : FeedData?
    if previous_data && (prev_favicon_data = previous_data.favicon_data)
      favicon_path = FaviconStorage.disk_path(prev_favicon_data)
      if favicon_path && File.exists?(favicon_path)
        favicon = prev_favicon_data.starts_with?("/favicons/") ? prev_favicon_data : cached.favicon
        return build_feed_data_with_favicon(cached, favicon, prev_favicon_data)
      end
    end

    cached_favicon = cached.favicon_data
    if cached_favicon.is_a?(String) && cached_favicon.starts_with?("/favicons/")
      favicon_path = FaviconStorage.disk_path(cached_favicon)
      unless favicon_path && File.exists?(favicon_path)
        return build_feed_data_with_favicon(cached, cached.favicon, nil)
      end
    end

    cached
  end

  private def build_feed_data_with_favicon(feed : FeedData, favicon : String?, favicon_data : String?) : FeedData
    FeedData.new(
      title: feed.title,
      url: feed.url,
      site_link: feed.site_link,
      header_color: feed.header_color,
      header_text_color: feed.header_text_color,
      items: feed.items,
      etag: feed.etag,
      last_modified: feed.last_modified,
      favicon: favicon,
      favicon_data: favicon_data,
      header_theme_colors: feed.header_theme_colors,
    )
  end
end
