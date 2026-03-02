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

    # Try JSON API first, fall back to RSS if blocked
    begin
      items = fetch_reddit_posts(subreddit, sort, limit, over18)
    rescue ex : Exception
      # JSON API failed (likely blocked), try RSS fallback
      begin
        items = fetch_reddit_rss(subreddit, sort, limit, over18)
      rescue rss_ex : Exception
        # Both methods failed
        return error_feed_data(feed, "Reddit blocked: #{ex.message}")
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
      
      response = client.get(uri.request_target, headers: headers)
    rescue ex : Socket::ConnectError
      raise RedditFetchError.new("Connection failed: #{ex.message}")
    rescue ex : OpenSSL::SSL::Error
      raise RedditFetchError.new("SSL error: #{ex.message}")
    rescue ex : IO::Error
      raise RedditFetchError.new("IO error: #{ex.message}")
    rescue ex : JSON::ParseException
      raise RedditFetchError.new("JSON parse error: #{ex.message}")
    rescue ex : Exception
      raise RedditFetchError.new("#{ex.class}: #{ex.message}")
    end

    case response.status_code
    when 200
      parse_reddit_response(response.body, limit, over18)
    when 403
      raise RedditFetchError.new("Access denied (403) - Reddit may be blocking this request")
    when 404
      raise RedditFetchError.new("Subreddit '#{subreddit}' not found")
    when 429
      raise RedditFetchError.new("Rate limited by Reddit API")
    when 503
      raise RedditFetchError.new("Reddit service unavailable")
    else
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
    # Reddit uses Atom format, not RSS 2.0
    url = "https://old.reddit.com/r/#{subreddit}/#{sort}.rss"
    headers = HTTP::Headers{
      "User-Agent" => USER_AGENT,
    }

    response = HTTP::Client.get(url, headers: headers)
    
    if response.status_code != 200
      raise RedditFetchError.new("RSS HTTP error #{response.status_code}")
    end

    # Parse Atom XML
    xml = XML.parse(response.body)
    items = [] of Item
    
    # Use local-name() to avoid namespace prefix issues
    # Reddit uses Atom format with <entry> elements, not RSS <item>
    xml.xpath_nodes("//*[local-name()='entry']").each do |node|
      break if items.size >= limit
      
      # Extract child elements using local-name() to avoid namespace issues
      title_node = node.xpath_node("*[local-name()='title']")
      link_node = node.xpath_node("*[local-name()='link']")
      updated_node = node.xpath_node("*[local-name()='updated']")
      
      title = title_node.try(&.inner_text) || "Untitled"
      # Atom link has href attribute
      link = link_node.try(&.["href"]) || ""
      
      pub_date = nil
      if updated_node
        updated_str = updated_node.inner_text
        begin
          # Atom uses ISO 8601 format
          pub_date = Time.parse_iso8601(updated_str)
        rescue
          # Ignore parse errors
        end
      end

      items << Item.new(title, link, pub_date) if link.size > 0
    end

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
