require "fetcher"
require "./models"
require "./fetcher/favicon"
require "./color_extractor"

module FetcherAdapter
  def self.pull_feed(feed : Feed, previous_data : FeedData?, limit : Int32 = 100) : FetchResult
    etag = previous_data.try(&.etag)
    last_modified = previous_data.try(&.last_modified)

    STDERR.puts "[DEBUG] FetcherAdapter.pull_feed: #{feed.url}"

    if feed.url.includes?("reddit.com/r/")
      cache_hit, result = fetch_reddit_feed(feed.url, limit, etag, last_modified)
      if cache_hit && previous_data
        STDERR.puts "[DEBUG] Reddit feed cache hit - returning cached data"
        cached = previous_data
        cached_with_headers = FeedData.new(
          cached.title,
          cached.url,
          cached.site_link,
          cached.header_color,
          cached.header_text_color,
          cached.items,
          result.etag,
          result.last_modified,
          cached.favicon,
          cached.favicon_data
        )
        return Result(FeedData, String).success(cached_with_headers)
      end
    else
      result = Fetcher.pull(feed.url, HTTP::Headers.new, etag, last_modified, limit)
    end

    STDERR.puts "[DEBUG] Fetcher result - error: #{result.error_message.inspect}, entries count: #{result.entries.size}"

    if error = result.error_message
      STDERR.puts "[DEBUG] Fetcher error: #{error}"
      return Result(FeedData, String).failure(error)
    end

    items = result.entries.map do |entry|
      Item.new(entry.title, entry.url, entry.published_at)
    end

    if items.empty?
      STDERR.puts "[DEBUG] No items found for #{feed.url}"
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

  private def self.fetch_reddit_feed(url : String, limit : Int32, etag : String?, last_modified : String?) : {Bool, Fetcher::Result}
    begin
      json_url = "#{url}/hot.json?limit=#{limit}&raw_json=1"
      STDERR.puts "[DEBUG] Fetching Reddit JSON: #{json_url}"
      entries, res_etag, res_last_modified, cache_hit = fetch_reddit_json(json_url, limit, etag, last_modified)
      return {cache_hit, build_reddit_result(entries, url, res_etag, res_last_modified)}
    rescue ex
      STDERR.puts "[DEBUG] Reddit JSON failed: #{ex.message}, trying RSS fallback"
    end

    begin
      rss_url = "#{url}.rss"
      STDERR.puts "[DEBUG] Fetching Reddit RSS: #{rss_url}"
      entries, res_etag, res_last_modified, cache_hit = fetch_reddit_rss(rss_url, limit, etag, last_modified)
      return {cache_hit, build_reddit_result(entries, url, res_etag, res_last_modified)}
    rescue ex
      return {false, Fetcher::Result.new(
        [] of Fetcher::Entry,
        nil,
        nil,
        nil,
        nil,
        Fetcher::Error.new(Fetcher::ErrorKind::HTTPError, "Reddit fetch failed: #{ex.message}"),
        nil,
        nil,
        nil,
        [] of Fetcher::Author
      )}
    end
  end

  private def self.fetch_reddit_json(url : String, limit : Int32, etag : String?, last_modified : String?) : {Array(Fetcher::Entry), String?, String?, Bool}
    headers = HTTP::Headers{
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    }

    if etag
      headers["If-None-Match"] = etag
    end
    if last_modified
      headers["If-Modified-Since"] = last_modified
    end

    response = HTTP::Client.get(url, headers: headers)

    if response.status_code == 304
      STDERR.puts "[DEBUG] Reddit JSON cache hit (304)"
      return {[] of Fetcher::Entry, etag, last_modified, true}
    end

    if response.status_code != 200
      raise "Reddit API returned #{response.status_code}"
    end

    res_etag = response.headers["ETag"]?
    res_last_modified = response.headers["Last-Modified"]?

    json = JSON.parse(response.body)
    entries = [] of Fetcher::Entry

    data = json["data"]?
    return {entries, res_etag, res_last_modified, false} unless data

    posts = data["children"]?
    return {entries, res_etag, res_last_modified, false} unless posts

    posts.as_a.each do |child|
      break if entries.size >= limit
      post = child["data"]

      title = post["title"]?.to_s
      permalink = post["permalink"]?.to_s
      is_self = post["is_self"]?.try(&.as_bool) || false
      url_val = post["url"]?.to_s

      link = is_self ? "https://www.reddit.com#{permalink}" : url_val
      pub_date = nil
      created_raw = post["created_utc"]?
      if created_raw
        begin
          created = created_raw.as_i.to_i64
          pub_date = Time.unix(created) if created > 0
        rescue
        end
      end

      entries << Fetcher::Entry.new(
        title: title,
        url: link,
        source_type: Fetcher::SourceType::Reddit,
        content: "",
        content_html: nil,
        author: nil,
        author_url: nil,
        categories: [] of String,
        attachments: [] of Fetcher::Attachment,
        published_at: pub_date,
        version: nil
      )
    end

    {entries, res_etag, res_last_modified, false}
  end

  private def self.fetch_reddit_rss(url : String, limit : Int32, etag : String?, last_modified : String?) : {Array(Fetcher::Entry), String?, String?, Bool}
    headers = HTTP::Headers{
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    }

    if etag
      headers["If-None-Match"] = etag
    end
    if last_modified
      headers["If-Modified-Since"] = last_modified
    end

    response = HTTP::Client.get(url, headers: headers)

    if response.status_code == 304
      STDERR.puts "[DEBUG] Reddit RSS cache hit (304)"
      return {[] of Fetcher::Entry, etag, last_modified, true}
    end

    if response.status_code != 200
      raise "Reddit RSS returned #{response.status_code}"
    end

    res_etag = response.headers["ETag"]?
    res_last_modified = response.headers["Last-Modified"]?

    xml = XML.parse(response.body)
    entries = [] of Fetcher::Entry

    xml.xpath_nodes("//*[local-name()='entry']").each do |node|
      break if entries.size >= limit

      title_node = node.xpath_node("*[local-name()='title']")
      link_node = node.xpath_node("*[local-name()='link']")
      updated_node = node.xpath_node("*[local-name()='updated']")

      title = title_node.try(&.inner_text) || "Untitled"
      link = link_node.try(&.["href"]) || ""

      pub_date = nil
      if updated_node
        begin
          pub_date = Time.parse_iso8601(updated_node.inner_text)
        rescue
        end
      end

      entries << Fetcher::Entry.new(
        title: title,
        url: link,
        source_type: Fetcher::SourceType::Reddit,
        content: "",
        content_html: nil,
        author: nil,
        author_url: nil,
        categories: [] of String,
        attachments: [] of Fetcher::Attachment,
        published_at: pub_date,
        version: nil
      ) if link.size > 0
    end

    {entries, res_etag, res_last_modified, false}
  end

  private def self.build_reddit_result(items : Array(Fetcher::Entry), url : String, etag : String?, last_modified : String?) : Fetcher::Result
    Fetcher::Result.new(
      items,
      etag,
      last_modified,
      url,
      nil,
      nil,
      nil,
      nil,
      nil,
      [] of Fetcher::Author
    )
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
