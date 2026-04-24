require "uri"

class QuickHeadlines::ConfigValidationError < Exception
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

  config.feeds.each do |feed|
    reason = invalid_url_reason(feed.url)
    invalid_feeds << {feed.title, feed.url, reason} if reason
  end

  config.tabs.each do |tab|
    tab.feeds.each do |feed|
      reason = invalid_url_reason(feed.url)
      invalid_feeds << {feed.title, feed.url, reason} if reason
    end
  end

  return if invalid_feeds.empty?

  raise QuickHeadlines::ConfigValidationError.new(invalid_feeds)
end

private def invalid_url_reason(url : String) : String?
  return "URL is empty" if url.strip.empty?

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
