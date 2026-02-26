require "./fetcher/entry"
require "./fetcher/result"
require "./fetcher/http_client_pool"
require "./fetcher/driver"
require "./fetcher/drivers/rss_driver"
require "./fetcher/drivers/reddit_driver"
require "./fetcher/drivers/software_driver"

module Fetcher
  DEFAULT_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  class Fetcher
    def self.pull(url : String, headers : HTTP::Headers = HTTP::Headers.new, limit : Int32 = 100) : Result
      driver = detect_driver(url)

      final_headers = build_headers(headers)

      driver.pull(url, final_headers, nil, nil, limit)
    end

    def self.pull(url : String, headers : HTTP::Headers, etag : String?, last_modified : String?, limit : Int32 = 100) : Result
      driver = detect_driver(url)

      final_headers = build_headers(headers)

      final_headers["If-None-Match"] = etag if etag
      final_headers["If-Modified-Since"] = last_modified if last_modified

      driver.pull(url, final_headers, etag, last_modified, limit)
    end

    private def self.detect_driver(url : String) : Driver
      if url.includes?("reddit.com/r/")
        RedditDriver.new
      elsif url.includes?("github.com") && url.includes?("/releases")
        SoftwareDriver.new
      elsif url.includes?("gitlab.com") && url.includes?("/-/releases")
        SoftwareDriver.new
      elsif url.includes?("codeberg.org") && url.includes?("/releases")
        SoftwareDriver.new
      else
        RSSDriver.new
      end
    end

    private def self.build_headers(custom_headers : HTTP::Headers) : HTTP::Headers
      headers = HTTP::Headers{
        "User-Agent"      => DEFAULT_USER_AGENT,
        "Accept"         => "application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.7",
        "Accept-Language" => "en-US,en;q=0.9",
        "Connection"     => "keep-alive",
      }

      custom_headers.each do |key, value|
        headers[key] = value
      end

      headers
    end
  end
end
