require "fetcher"
require "./models"
require "./fetcher/favicon"
require "./color_extractor"

module FetcherAdapter
  def self.pull_feed(feed : Feed, previous_data : FeedData?, limit : Int32 = 100) : FetchResult
    etag = previous_data.try(&.etag)
    last_modified = previous_data.try(&.last_modified)

    debug_log("FetcherAdapter.pull_feed: #{feed.url}")

    if feed.url.includes?("reddit.com/r/")
      result = fetch_reddit_feed(feed.url, limit)
    else
      result = Fetcher.pull(feed.url, HTTP::Headers.new, etag, last_modified, limit)
    end

    debug_log("Fetcher result - error: #{result.error_message.inspect}, entries count: #{result.entries.size}")

    if error = result.error_message
      debug_log("Fetcher error: #{error}")
      return Result(FeedData, String).failure(error)
    end

    items = result.entries.map do |entry|
      Item.new(entry.title, entry.url, entry.published_at)
    end

    if items.empty?
      debug_log("No items found for #{feed.url}")
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

  private def self.fetch_reddit_feed(url : String, limit : Int32) : Fetcher::Result
    begin
      json_url = "#{url}/hot.json?limit=#{limit}&raw_json=1"
      debug_log("Fetching Reddit JSON: #{json_url}")
      items = fetch_reddit_json(json_url, limit)
      return build_reddit_result(items, url)
    rescue ex
      debug_log("Reddit JSON failed: #{ex.message}, trying RSS fallback")
    end

    begin
      rss_url = "#{url}.rss"
      debug_log("Fetching Reddit RSS: #{rss_url}")
      items = fetch_reddit_rss(rss_url, limit)
      build_reddit_result(items, url)
    rescue ex
      Fetcher::Result.new(
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
      )
    end
  end

  private def self.fetch_reddit_json(url : String, limit : Int32) : Array(Fetcher::Entry)
    headers = HTTP::Headers{
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    }

    response = HTTP::Client.get(url, headers: headers)
    if response.status_code != 200
      raise "Reddit API returned #{response.status_code}"
    end

    json = JSON.parse(response.body)
    entries = [] of Fetcher::Entry

    data = json["data"]?
    return entries unless data

    posts = data["children"]?
    return entries unless posts

    posts.as_a.each do |child|
      break if entries.size >= limit
      post = child["data"]

      title = post["title"]?.to_s
      permalink = post["permalink"]?.to_s
      is_self = post["is_self"]?.try(&.as_bool) || false
      url_val = post["url"]?.to_s
      created_raw = post["created_utc"]?

      link = is_self ? "https://www.reddit.com#{permalink}" : url_val
      pub_date = nil
      if created_raw
        begin
          created = created_raw.as_f.to_i64
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

    entries
  end

  private def self.fetch_reddit_rss(url : String, limit : Int32) : Array(Fetcher::Entry)
    headers = HTTP::Headers{
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    }

    response = HTTP::Client.get(url, headers: headers)
    if response.status_code != 200
      raise "Reddit RSS returned #{response.status_code}"
    end

    xml = XML.parse(response.body)
    entries = [] of Fetcher::Entry

    xml.xpath_nodes("//*[local-name()='entry']").each do |node|
      break if entries.size >= limit

      title_node = node.xpath_node("*[local-name()='title']")
      link_node = node.xpath_node("*[local-name()='link']")
      updated_node = node.xpath_node("*[local-name()='updated']")
      published_node = node.xpath_node("*[local-name()='published']")

      title = title_node.try(&.inner_text) || "Untitled"
      link = link_node.try(&.["href"]) || ""

      pub_date = nil
      time_node = updated_node || published_node
      if time_node
        begin
          pub_date = Time.parse_iso8601(time_node.inner_text)
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

    entries
  end

  private def self.build_reddit_result(items : Array(Fetcher::Entry), url : String) : Fetcher::Result
    Fetcher::Result.new(
      items,
      nil,
      nil,
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
