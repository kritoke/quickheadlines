require "json"
require "time"
require "xml"
require "./config"
require "./models"
require "./storage"
require "./health_monitor"
require "./color_extractor"

module RedditFetcher
  USER_AGENT      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  REDDIT_API_BASE = "https://www.reddit.com"

  struct RedditPost
    include JSON::Serializable
    property title : String
    property url : String
    property permalink : String
    property created_utc : Float64
    property author : String
    property num_comments : Int32
    @[JSON::Field(key: "over_18")]
    getter? over18 : Bool = false
    @[JSON::Field(key: "is_self")]
    getter? self_post : Bool = false

    def self_post? : Bool
      @self_post
    end

    property selftext : String?

    def self? : Bool
      @self_post
    end
  end

  struct RedditChild
    include JSON::Serializable
    property kind : String
    property data : RedditPost
  end

  struct RedditData
    include JSON::Serializable
    property children : Array(RedditChild)
    property after : String?
  end

  struct RedditListing
    include JSON::Serializable
    property kind : String
    property data : RedditData
  end

  def self.fetch_subreddit(feed : Feed, limit : Int32) : FeedData
    subreddit = feed.subreddit
    return error_feed_data(feed, "No subreddit configured") unless subreddit

    sort = feed.sort
    over18 = feed.over18? || false

    site_link = "https://www.reddit.com/r/#{subreddit}"
    feed_title = "r/#{subreddit}"

    STDERR.puts "[RSS-FALLBACK-ENABLED] Version 2026-03-01-11:00"
    STDERR.puts "[DEBUG] fetch_subreddit called for #{subreddit}, limit=#{limit}"

    # Try JSON API first, fall back to RSS if blocked
    json_failed = false
    json_error_msg = ""
    begin
      STDERR.puts "[DEBUG] About to call fetch_reddit_posts for #{subreddit}"
      items = fetch_reddit_posts(subreddit, sort, limit, over18)
      STDERR.puts "[INFO] Reddit JSON API succeeded for #{subreddit}: #{items.size} items"
    rescue ex : Exception
      json_failed = true
      json_error_msg = "#{ex.class}: #{ex.message}"
      STDERR.puts "[WARN] Reddit JSON API failed for #{subreddit}: #{json_error_msg}"
      STDERR.puts "[WARN] Trying RSS fallback..."
      
      begin
        STDERR.puts "[DEBUG] Attempting RSS fetch for #{subreddit}..."
        items = fetch_reddit_rss(subreddit, sort, limit, over18)
        STDERR.puts "[INFO] ✓ Reddit RSS fallback succeeded for #{subreddit}: #{items.size} items"
      rescue rss_ex : Exception
        STDERR.puts "[ERROR] ✗ RSS fallback also failed for #{subreddit}: #{rss_ex.class}: #{rss_ex.message}"
        STDERR.puts "[ERROR] JSON error was: #{json_error_msg}"
        return error_feed_data(feed, "Reddit blocked: #{json_error_msg}")
      end
    end

    favicon = fetch_subreddit_favicon(subreddit)
    header_color = "ff4500"
    header_text_color = "ffffff"

    FeedData.new(
      feed_title,
      feed.url,
      site_link,
      header_color,
      header_text_color,
      items,
      nil,
      nil,
      favicon,
      nil
    )
  end

  def self.fetch_reddit_posts(subreddit : String, sort : String, limit : Int32, over18 : Bool) : Array(Item)
    url = "#{REDDIT_API_BASE}/r/#{subreddit}/#{sort}.json?limit=#{limit}&raw_json=1"
    uri = URI.parse(url)
    
    # Use realistic browser headers to avoid being blocked by Reddit
    headers = HTTP::Headers{
      "User-Agent"      => USER_AGENT,
      "Accept"          => "application/json, text/javascript, */*",
      "Accept-Language" => "en-US,en;q=0.9",
      "Origin"          => "https://www.reddit.com",
      "Referer"         => "https://www.reddit.com/",
    }

    begin
      client = HTTP::Client.new(uri)
      client.connect_timeout = 30.seconds
      client.read_timeout = 30.seconds
      
      STDERR.puts "[DEBUG] Reddit HTTP request starting for #{subreddit}"
      STDERR.puts "[DEBUG] URL: #{url}"
      
      response = client.get(uri.request_target, headers: headers)
      
      STDERR.puts "[DEBUG] Reddit HTTP response for #{subreddit}: #{response.status_code}"
      STDERR.puts "[DEBUG] Response headers: #{response.headers.to_s}"
      STDERR.puts "[DEBUG] Response body length: #{response.body.bytesize} bytes"
      
      # Log first 500 chars of response body for debugging
      body_preview = response.body.size > 500 ? response.body[0..499] + "..." : response.body
      STDERR.puts "[DEBUG] Response body preview: #{body_preview}"
      
      STDERR.puts "[DEBUG] About to parse Reddit response for #{subreddit}"
      result = parse_reddit_response(response.body, limit, over18)
      STDERR.puts "[DEBUG] Successfully parsed #{result.size} items for #{subreddit}"
      result
    rescue ex : Socket::ConnectError
      STDERR.puts "[ERROR] Reddit connection failed for #{subreddit}: #{ex.class} - #{ex.message}"
      STDERR.puts "[ERROR] Full exception: #{ex.inspect_with_backtrace}"
      raise RedditFetchError.new("Connection failed: #{ex.class} - #{ex.message}")
    rescue ex : OpenSSL::SSL::Error
      STDERR.puts "[ERROR] Reddit SSL error for #{subreddit}: #{ex.class} - #{ex.message}"
      STDERR.puts "[ERROR] Full exception: #{ex.inspect_with_backtrace}"
      raise RedditFetchError.new("SSL error: #{ex.class} - #{ex.message}")
    rescue ex : IO::Error
      STDERR.puts "[ERROR] Reddit IO error for #{subreddit}: #{ex.class} - #{ex.message}"
      STDERR.puts "[ERROR] Full exception: #{ex.inspect_with_backtrace}"
      raise RedditFetchError.new("IO error: #{ex.class} - #{ex.message}")
    rescue ex : JSON::ParseException
      STDERR.puts "[ERROR] Reddit JSON parse error for #{subreddit}: #{ex.class} - #{ex.message}"
      STDERR.puts "[ERROR] Full exception: #{ex.inspect_with_backtrace}"
      raise RedditFetchError.new("JSON parse error: #{ex.message}")
    rescue ex : Exception
      STDERR.puts "[ERROR] Reddit unexpected error for #{subreddit}: #{ex.class} - #{ex.message}"
      STDERR.puts "[ERROR] Message: #{ex.message}"
      STDERR.puts "[ERROR] Full exception: #{ex.inspect_with_backtrace}"
      raise RedditFetchError.new("Unexpected error: #{ex.class} - #{ex.message}")
    end

    case response.status_code
    when 200
      parse_reddit_response(response.body, limit, over18)
    when 403
      STDERR.puts "[DEBUG] Reddit returned 403 for #{subreddit} - User-Agent may be blocked"
      raise RedditFetchError.new("Access denied (403) - Reddit may be blocking this request")
    when 404
      raise RedditFetchError.new("Subreddit '#{subreddit}' not found")
    when 429
      STDERR.puts "[DEBUG] Reddit rate limited for #{subreddit}"
      raise RedditFetchError.new("Rate limited by Reddit API")
    when 503
      raise RedditFetchError.new("Reddit service unavailable")
    else
      STDERR.puts "[DEBUG] Reddit HTTP #{response.status_code} for #{subreddit}"
      raise RedditFetchError.new("HTTP error #{response.status_code}")
    end
  end

  def self.parse_reddit_response(body : String, limit : Int32, over18 : Bool) : Array(Item)
    parsed = JSON.parse(body)
    listing = RedditListing.from_json(parsed.to_json)

    items = [] of Item
    listing.data.children.each do |child|
      post = child.data

      next if post.over18? && !over18

      link = resolve_reddit_link(post)
      pub_date = Time.unix(post.created_utc.to_i64) if post.created_utc > 0

      items << Item.new(
        post.title,
        link,
        pub_date
      )

      break if items.size >= limit
    end

    items
  end

  def self.resolve_reddit_link(post : RedditPost) : String
    if post.self?
      "https://www.reddit.com#{post.permalink}"
    elsif post.selftext
      "https://www.reddit.com#{post.permalink}"
    else
      post.url
    end
  end

  def self.fetch_reddit_rss(subreddit : String, sort : String, limit : Int32, over18 : Bool) : Array(Item)
    # Use old.reddit.com RSS - less restrictive than new Reddit
    url = "https://old.reddit.com/r/#{subreddit}/#{sort}.rss"
    headers = HTTP::Headers{
      "User-Agent" => USER_AGENT,
    }

    STDERR.puts "[DEBUG] RSS URL: #{url}"
    response = HTTP::Client.get(url, headers: headers)
    
    if response.status_code != 200
      STDERR.puts "[ERROR] RSS HTTP #{response.status_code}"
      raise RedditFetchError.new("RSS HTTP error #{response.status_code}")
    end

    STDERR.puts "[DEBUG] RSS response length: #{response.body.bytesize} bytes"

    # Parse RSS XML
    xml = XML.parse(response.body)
    items = [] of Item
    
    STDERR.puts "[DEBUG] RSS XML parsed, looking for items..."
    
    # Reddit RSS uses atom namespace, try different selectors
    xml.xpath_nodes("//item").each do |node|
      STDERR.puts "[DEBUG] Found RSS item node"
      break if items.size >= limit
      
      # Extract child elements
      title_node = node.xpath_node("./title")
      link_node = node.xpath_node("./link")
      pubdate_node = node.xpath_node("./pubDate")
      
      title = title_node.try(&.inner_text) || "Untitled"
      link = link_node.try(&.inner_text) || ""
      
      STDERR.puts "[DEBUG] RSS item: title='#{title[0..50] rescue title}', link='#{link[0..50] rescue link}'"
      
      pub_date = nil
      if pubdate_node
        pub_date_str = pubdate_node.inner_text
        begin
          pub_date = Time.parse(pub_date_str, "%a, %d %b %Y %H:%M:%S %z", Time::Location.local)
        rescue
          # Ignore parse errors
        end
      end

      items << Item.new(title, link, pub_date) if link.size > 0
    end

    STDERR.puts "[DEBUG] RSS parsed #{items.size} items"
    items
  end

  def self.fetch_subreddit_favicon(subreddit : String) : String?
    site_link = "https://www.reddit.com/r/#{subreddit}"
    FaviconHelper.google_favicon_url(site_link, "")
  end

  def self.error_feed_data(feed : Feed, message : String) : FeedData
    site_link = "https://www.reddit.com"
    FeedData.new(
      feed.title,
      feed.url,
      site_link,
      "ff4500",
      "ffffff",
      [] of Item,
      nil,
      nil,
      FaviconHelper.google_favicon_url(site_link, feed.url),
      nil,
      message
    )
  end

  class RedditFetchError < Exception
    def initialize(message : String)
      super(message)
    end
  end
end
