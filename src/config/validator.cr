require "uri"

def validate_feed(feed : Feed) : Bool
  return false unless valid_url?(feed)
  return false unless valid_item_limit?(feed)
  true
end

private def valid_url?(feed : Feed) : Bool
  url = feed.url

  return false if url.nil? || url.empty?

  unless url.starts_with?("http")
    STDERR.puts "[WARN] Invalid feed URL (must start with http/https): #{url}"
    return false
  end

  begin
    uri = URI.parse(url)
    host = uri.host
    if host.nil? || host.strip.empty?
      STDERR.puts "[WARN] Invalid feed URL (missing host): #{url}"
      return false
    end
  rescue
    STDERR.puts "[WARN] Invalid feed URL (parse error): #{url}"
    return false
  end

  true
end

private def valid_item_limit?(feed : Feed) : Bool
  limit = feed.item_limit
  return true unless limit

  if limit < 1
    STDERR.puts "[WARN] Invalid item_limit for '#{feed.title}' (must be >= 1), using global default"
    return false
  elsif limit > 100
    STDERR.puts "[WARN] High item_limit for '#{feed.title}' (#{limit}), may impact performance"
  end

  true
end

private def valid_subreddit_config?(feed : Feed) : Bool
  subreddit = feed.subreddit
  return true unless subreddit

  if subreddit.strip.empty?
    STDERR.puts "[WARN] Empty subreddit name for '#{feed.title}'"
    return false
  end

  if subreddit =~ /[^a-zA-Z0-9_-]/
    STDERR.puts "[WARN] Invalid subreddit name '#{subreddit}' for '#{feed.title}' (can only contain alphanumeric, underscore, hyphen)"
    return false
  end

  valid_sorts = ["hot", "new", "top", "rising", "controversial"]
  unless valid_sorts.includes?(feed.sort)
    STDERR.puts "[WARN] Invalid sort '#{feed.sort}' for '#{feed.title}' (must be: hot, new, top, rising, controversial)"
  end

  true
end

def validate_config_feeds(config : Config) : Array(Feed)
  valid_feeds = [] of Feed

  config.feeds.each do |feed|
    if validate_feed(feed)
      valid_feeds << feed
    else
      STDERR.puts "[WARN] Skipping invalid feed: #{feed.title} (#{feed.url})"
    end
  end

  config.tabs.each do |tab|
    tab.feeds.each do |feed|
      if validate_feed(feed)
        valid_feeds << feed
      else
        STDERR.puts "[WARN] Skipping invalid feed in tab '#{tab.name}': #{feed.title} (#{feed.url})"
      end
    end
  end

  valid_feeds
end

class ConfigValidationError < Exception
  getter invalid_feeds : Array({String, String, String})

  @msg : String

  def initialize(@invalid_feeds : Array({String, String, String}))
    @msg = "Invalid feed URLs found:\n"
    invalid_feeds.each do |(title, url, reason)|
      @msg = "#{@msg}  - #{title} (#{url}): #{reason}\n"
    end
  end

  def message : String
    @msg.strip
  end
end

def validate_feed_urls!(config : Config) : Nil
  invalid_feeds = [] of {String, String, String}

  collect_invalid_feeds(config, invalid_feeds)

  return if invalid_feeds.empty?

  raise ConfigValidationError.new(invalid_feeds)
end

private def collect_invalid_feeds(config : Config, invalid_feeds : Array({String, String, String})) : Nil
  config.feeds.each do |feed|
    reason = feed_url_invalid_reason(feed.url)
    invalid_feeds << {feed.title, feed.url, reason} if reason
  end

  config.tabs.each do |tab|
    tab.feeds.each do |feed|
      reason = feed_url_invalid_reason(feed.url)
      invalid_feeds << {feed.title, feed.url, reason} if reason
    end
  end
end

private def feed_url_invalid_reason(url : String) : String?
  return "URL is empty" if url.nil? || url.strip.empty?

  begin
    uri = URI.parse(url.strip)
    return "URL must have http or https scheme" unless uri.scheme
    return "URL must have http or https scheme" unless uri.scheme.in?("http", "https")
    return "URL must have a host" if !uri.host.is_a?(String) || uri.host.to_s.empty?
    nil
  rescue ex
    "URL is malformed: #{ex.message}"
  end
end
