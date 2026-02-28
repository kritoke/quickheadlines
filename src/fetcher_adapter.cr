require "fetcher"
require "./models"
require "./fetcher/favicon"
require "./color_extractor"

module FetcherAdapter
  def self.pull_feed(feed : Feed, previous_data : FeedData?, limit : Int32 = 100) : FetchResult
    etag = previous_data.try(&.etag)
    last_modified = previous_data.try(&.last_modified)

    result = Fetcher.pull(feed.url, HTTP::Headers.new, etag, last_modified, limit)

    if error = result.error_message
      return Result(FeedData, String).failure(error)
    end

    items = result.entries.map do |entry|
      Item.new(entry.title, entry.url, entry.published_at)
    end

    if items.empty?
      return Result(FeedData, String).failure("No items found")
    end

    site_link = result.site_link || feed.url
    favicon, favicon_data = get_favicon(feed, site_link, result.favicon, previous_data)

    local_favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)
    header_color, header_text_color = extract_header_colors_simple(feed, local_favicon_path)

    feed_data = FeedData.new(
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

    Result(FeedData, String).success(feed_data)
  rescue ex
    STDERR.puts "[ERROR] FetcherAdapter: #{ex.message}"
    Result(FeedData, String).failure("Error: #{ex.class}")
  end

  def self.configure_logger
    Fetcher.logger = ->(msg : String) { STDERR.puts "[Fetcher] #{msg}" }
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
end
