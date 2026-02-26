require "fetcher"
require "./models"
require "./fetcher/favicon"
require "./color_extractor"

module FetcherAdapter
  def self.pull_feed(feed : Feed, previous_data : FeedData?) : FeedData
    etag = previous_data.try(&.etag)
    last_modified = previous_data.try(&.last_modified)

    result = Fetcher::Fetcher.pull(feed.url, HTTP::Headers.new, etag, last_modified)

    if error = result.error_message
      return error_feed_data(feed, error)
    end

    items = result.entries.map do |entry|
      Item.new(entry.title, entry.url, entry.published_at)
    end

    if items.empty?
      return error_feed_data(feed, "No items found")
    end

    site_link = result.site_link || feed.url
    favicon, favicon_data = get_favicon(feed, site_link, result.favicon, previous_data)

    local_favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)
    header_color, header_text_color = extract_header_colors_simple(feed, local_favicon_path)

    FeedData.new(
      feed.title,
      feed.url,
      site_link,
      header_color,
      header_text_color,
      items,
      result.etag,
      result.last_modified,
      favicon,
      favicon_data
    )
  rescue ex
    STDERR.puts "[ERROR] FetcherAdapter: #{ex.message}"
    error_feed_data(feed, "Error: #{ex.class}")
  end

  private def self.extract_header_colors_simple(feed : Feed, favicon_path : String?) : {String?, String?}
    if favicon_path && favicon_path.starts_with?("/favicons/")
      begin
        extracted = ColorExtractor.theme_aware_extract_from_favicon(favicon_path, feed.url, feed.header_color)
        if extracted && extracted.is_a?(Hash)
          bg_val = extracted["bg"]?.to_s if extracted.has_key?("bg")
          text_val = extracted["text"]?.to_s if extracted.has_key?("text")
          return {bg_val, text_val}
        end
      rescue
      end
    end
    {feed.header_color, feed.header_text_color}
  end

  private def self.error_feed_data(feed : Feed, message : String) : FeedData
    site_link = feed.url
    STDERR.puts "[#{Time.local}] Feed error: #{feed.title} (#{feed.url}) - #{message}"

    favicon = FaviconHelper.google_favicon_url(site_link, feed.url)

    FeedData.new(
      feed.title,
      feed.url,
      site_link,
      feed.header_color,
      feed.header_text_color,
      [Item.new(message, feed.url, nil)],
      nil,
      nil,
      favicon,
      nil,
      message
    )
  end
end
