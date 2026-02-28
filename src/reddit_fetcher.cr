require "json"
require "time"
require "./config"
require "./models"
require "./storage"
require "./health_monitor"
require "./color_extractor"

module RedditFetcher
  USER_AGENT      = "QuickHeadlines/0.3 (Reddit Feed Fetcher)"
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

    begin
      items = fetch_reddit_posts(subreddit, sort, limit, over18)
      STDERR.puts "[DEBUG] Reddit fetched #{items.size} items for #{subreddit}"
    rescue ex : RedditFetchError
      msg = ex.message || "Unknown error"
      return error_feed_data(feed, msg)
    rescue ex
      HealthMonitor.log_error("fetch_subreddit(#{subreddit})", ex)
      msg = ex.message || ex.class.to_s
      return error_feed_data(feed, "Error: #{ex.class} - #{msg}")
    end

    favicon = fetch_subreddit_favicon(subreddit)

    header_color = "ff4500"

    FeedData.new(
      feed_title,
      feed.url,
      site_link,
      header_color,
      nil,
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
    headers = HTTP::Headers{
      "User-Agent" => USER_AGENT,
      "Accept"     => "application/json",
    }

    begin
      client = HTTP::Client.new(uri)
      client.connect_timeout = 30.seconds
      client.read_timeout = 30.seconds

      response = client.get(uri.request_target, headers: headers)
    rescue ex : Socket::ConnectError
      STDERR.puts "[DEBUG] Reddit connection failed for #{subreddit}: #{ex.message}"
      raise RedditFetchError.new("Connection failed: #{ex.message}")
    rescue ex : OpenSSL::SSL::Error
      STDERR.puts "[DEBUG] Reddit SSL error for #{subreddit}: #{ex.message}"
      raise RedditFetchError.new("SSL error: #{ex.message}")
    rescue ex : IO::Error
      STDERR.puts "[DEBUG] Reddit IO error for #{subreddit}: #{ex.message}"
      raise RedditFetchError.new("IO error: #{ex.message}")
    rescue ex
      STDERR.puts "[DEBUG] Reddit unexpected error for #{subreddit}: #{ex.class} - #{ex.message}"
      raise RedditFetchError.new("Unexpected error: #{ex.class} - #{ex.message}")
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
