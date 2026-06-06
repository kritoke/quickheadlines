require "uri"
require "./vug_adapter"
require "../favicon_storage"

# Favicon resolution logic extracted from FeedFetcher.
# Handles VugAdapter lookups, Google favicon fallbacks, and domain extraction.
module FetcherFavicon
  # Resolve favicon URL and data for a feed, with fallbacks.
  def resolve_favicons(site_link : String, feed : Feed, result_favicon, previous_data : FeedData?) : Tuple(String?, String?)
    favicon, favicon_data = safe_get_favicon_with_fallback(
      site_link,
      result_favicon,
      previous_data.try(&.favicon),
      previous_data.try(&.favicon_data)
    )

    if favicon.nil? && favicon_data.nil?
      domain = extract_domain_for_favicon(site_link, feed.url)
      if domain
        google_url = VugAdapter.google_favicon_url(domain)
        if saved = FaviconActor.instance.fetch_and_save(google_url)
          favicon = saved
          favicon_data = saved
        end
      end
    end

    {favicon, favicon_data}
  end

  # Extract a domain suitable for favicon lookup from site_link, falling back to feed URL.
  private def extract_domain_for_favicon(site_link : String, feed_url : String) : String?
    if site_link && !site_link.starts_with?("#") && !site_link.includes?("#") && !site_link.starts_with?("placeholder:") && site_link.presence
      uri = URI.parse(site_link)
      return uri.host if uri.host
    end
    uri = URI.parse(feed_url)
    uri.host
  end

  # Safe favicon getter with VugAdapter, catching DNS/timeout errors.
  private def safe_get_favicon_with_fallback(site_link : String, parsed_favicon : String?, prev_favicon : String?, prev_favicon_data : String?) : {String?, String?}
    VugAdapter.get_favicon(site_link, parsed_favicon, prev_favicon, prev_favicon_data)
  rescue ex : IO::TimeoutError | Socket::Addrinfo::Error
    Log.for("quickheadlines.feed").debug { "VugAdapter.get_favicon failed for #{site_link}: #{ex.class}" }
    {nil, nil}
  rescue ex
    Log.for("quickheadlines.feed").warn { "VugAdapter.get_favicon unexpected error for #{site_link}: #{ex.class} - #{ex.message}" }
    {nil, nil}
  end
end
