require "json"
require "../driver"
require "../http_client_pool"

module Fetcher
  class RedditDriver < Driver
    USER_AGENT      = "QuickHeadlines/0.3 (Reddit Feed Fetcher)"
    REDDIT_API_BASE = "https://www.reddit.com"

    def pull(url : String, headers : HTTP::Headers, etag : String?, last_modified : String?, limit : Int32 = 100) : Result
      subreddit = extract_subreddit(url)
      return build_error_result("Not a Reddit subreddit URL") unless subreddit

      sort = extract_sort(url)
      actual_limit = Math.min(limit, 25)

      with_retry do
        fetch_reddit(subreddit, sort, actual_limit)
      end
    rescue ex : RetriableError
      build_error_result("Failed after retries: #{ex.message}")
    rescue ex : RedditFetchError
      build_error_result(ex.message || "Reddit fetch error")
    rescue ex
      build_error_result("#{ex.class}: #{ex.message}")
    end

    private def fetch_reddit(subreddit : String, sort : String, limit : Int32) : Result
      url = "#{REDDIT_API_BASE}/r/#{subreddit}/#{sort}.json?limit=#{limit}&raw_json=1"
      headers = HTTP::Headers{
        "User-Agent" => USER_AGENT,
        "Accept"     => "application/json",
      }

      uri = URI.parse(url)
      client = HTTPClientPool.clientFor(uri)
      response = client.get(uri.request_target, headers: headers)

      case response.status_code
      when 200
        items = parse_reddit_response(response.body, limit)
        site_link = "https://www.reddit.com/r/#{subreddit}"
        favicon = "https://www.reddit.com/favicon.ico"

        Result.new(
          entries: items,
          etag: nil,
          last_modified: nil,
          site_link: site_link,
          favicon: favicon,
          error_message: nil
        )
      when 404
        raise RedditFetchError.new("Subreddit '#{subreddit}' not found")
      when 429
        raise RetriableError.new("Rate limited by Reddit API")
      when 503
        raise RetriableError.new("Reddit service unavailable")
      else
        raise RedditFetchError.new("HTTP error #{response.status_code}")
      end
    end

    private def extract_subreddit(url : String) : String?
      match = url.match(%r{reddit\.com/r/([^/]+)}i)
      match ? match[1] : nil
    end

    private def extract_sort(url : String) : String
      if url.includes?("/top.")
        "top"
      elsif url.includes?("/new.")
        "new"
      elsif url.includes?("/rising.")
        "rising"
      else
        "hot"
      end
    end

    private def parse_reddit_response(body : String, limit : Int32) : Array(Entry)
      parsed = JSON.parse(body)
      children = parsed[0]["data"]?.try(&.["children"]?)

      if children.nil?
        return [] of Entry
      end

      children_array = children.is_a?(Array) ? children : [] of JSON::Any

      entries = [] of Entry
      children_array.each do |child|
        post = child["data"]?
        next unless post

        title = post["title"]?.try(&.as_s) || "Untitled"
        post_url = post["url"]?.try(&.as_s) || ""
        permalink = post["permalink"]?.try(&.as_s) || ""
        created_utc = post["created_utc"]?.try(&.as_f) || 0.0
        is_self = post["is_self"]?.try(&.as_bool) || false

        link = resolve_reddit_link(post_url, permalink, is_self)
        pub_date = created_utc > 0 ? Time.unix(created_utc.to_i64) : nil

        entries << Entry.new(title, link, "", nil, pub_date, "reddit", nil)

        break if entries.size >= limit
      end

      entries
    end

    private def resolve_reddit_link(post_url : String, permalink : String, is_self : Bool) : String
      if is_self || post_url.empty?
        "https://www.reddit.com#{permalink}"
      else
        post_url
      end
    end

    class RedditFetchError < Exception
    end
  end
end
