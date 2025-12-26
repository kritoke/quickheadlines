require "base64"
require "gc"

def fetch_favicon_data_uri(url : String) : String?
  current_url = url
  redirects = 0

  loop do
    return if redirects > 3

    uri = URI.parse(current_url)
    client = POOL.for(current_url)
    headers = HTTP::Headers{"User-Agent" => "Mozilla/5.0 (compatible; QuickHeadlines/1.0)"}

    begin
      client.get(uri.request_target, headers: headers) do |response|
        if response.status.redirection? && (location = response.headers["Location"]?)
          current_url = uri.resolve(location).to_s
          redirects += 1
        elsif response.status.success?
          content_type = response.content_type || "image/png"
          data = Base64.strict_encode(response.body_io.getb_to_end)
          return "data:#{content_type};base64,#{data}"
        else
          return
        end
      end
    rescue
      return
    ensure
      client.close
    end
  end
end

private def fetch_favicon(feed : Feed, site_link : String, parsed_favicon : String?, previous_data : FeedData?) : {String?, String?}
  favicon = parsed_favicon

  # Resolve relative favicon URLs
  if favicon && !favicon.starts_with?("http")
    favicon = resolve_url(favicon, site_link.presence || feed.url)
  end

  if favicon.nil?
    begin
      if host = URI.parse(site_link).host
        favicon = "https://www.google.com/s2/favicons?domain=#{host}&sz=128"
      end
    rescue
    end
  end

  # Fetch/Cache Favicon Data
  favicon_data = nil
  if favicon
    if previous_data && previous_data.favicon == favicon && previous_data.favicon_data
      favicon_data = previous_data.favicon_data
    else
      favicon_data = fetch_favicon_data_uri(favicon)
    end
  end

  {favicon, favicon_data}
end

def fetch_feed(feed : Feed, item_limit : Int32, previous_data : FeedData? = nil) : FeedData
  uri = URI.parse(feed.url)
  client = POOL.for(feed.url)
  headers = HTTP::Headers{
    "User-Agent" => "QuickHeadlines/1.0",
    "Accept"     => "application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8",
  }

  if previous_data
    previous_data.etag.try { |v| headers["If-None-Match"] = v }
    previous_data.last_modified.try { |v| headers["If-Modified-Since"] = v }
  end

  begin
    client.get(uri.request_target, headers: headers) do |response|
      if response.status_code == 304 && previous_data
        # Content hasn't changed, return previous data
        return previous_data
      end

      unless response.status.success?
        # Fall back to an error message in the body box
        return FeedData.new(
          feed.title,
          feed.url,
          feed.url,
          feed.header_color,
          [Item.new("Error fetching feed (status #{response.status_code})", feed.url, nil)]
        )
      end

      parsed = parse_feed(response.body_io, item_limit)
      items = parsed[:items]
      site_link = parsed[:site_link] || feed.url

      favicon, favicon_data = fetch_favicon(feed, site_link, parsed[:favicon], previous_data)

      # Capture caching headers
      etag = response.headers["ETag"]?
      last_modified = response.headers["Last-Modified"]?

      if items.empty?
        # Show a single placeholder item linking to the feed itself
        items = [Item.new("No items found (or unsupported format)", feed.url, nil)]
      end
      FeedData.new(feed.title, feed.url, site_link, feed.header_color, items, etag, last_modified, favicon, favicon_data)
    end
  ensure
    client.close
  end
rescue ex
  FeedData.new(
    feed.title,
    feed.url,
    feed.url,
    feed.header_color,
    [Item.new("Error: #{ex.message}", feed.url, nil)]
  )
end

def refresh_all(config : Config)
  STATE.config_title = config.page_title
  STATE.config = config

  # Create a map of existing feeds to preserve cache data
  previous_feeds = STATE.feeds.index_by(&.url)

  channel = Channel(Tuple(Int32, FeedData)).new

  config.feeds.each_with_index do |feed, index|
    spawn do
      SEM.receive
      begin
        prev = previous_feeds[feed.url]?
        data = fetch_feed(feed, config.item_limit, prev)
        channel.send({index, data})
      ensure
        SEM.send(nil)
      end
    end
  end

  results = Array(FeedData?).new(config.feeds.size, nil)
  config.feeds.size.times do
    index, data = channel.receive
    results[index] = data
  end
  new_feeds = results.compact

  STATE.update(new_feeds, Time.local)

  # Clear memory after large amount of data processing
  GC.collect
end

def start_refresh_loop(config_path : String)
  # Load once and set baseline mtime
  active_config = load_config(config_path)
  last_mtime = File.info(config_path).modification_time

  # Do an initial refresh with the active config
  refresh_all(active_config)
  puts "[#{Time.local}] Initial refresh complete"

  spawn do
    loop do
      begin
        # Check if config file changed
        current_mtime = File.info(config_path).modification_time

        if current_mtime > last_mtime
          new_config = load_config(config_path)
          active_config = new_config
          last_mtime = current_mtime

          puts "[#{Time.local}] Config change detected. Reloaded feeds.yml"
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed after config change"
        else
          # Periodic refresh with existing config to fetch new items
          refresh_all(active_config)
          puts "[#{Time.local}] Refreshed feeds and ran GC"
        end

        # Sleep based on current config's interval
        sleep (active_config.refresh_minutes * 60).seconds
      rescue ex
        puts "Error refresh loop: #{ex.message}"
        sleep 1.minute # Safety sleep so errors don't loop instantly
      end
    end
  end
end
