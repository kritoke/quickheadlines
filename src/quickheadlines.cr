require "yaml"
require "http/server"
require "http/client"
require "xml"
require "slang"
require "html"
require "gc"
require "uri"

# ----- Compile-time embedded templates -----

# These files must exist at compile time in the src directory
LAYOUT_SOURCE = {{ read_file("src/layout.slang") }}.gsub('\u00A0', ' ') # remove possible bad spaces
CSS_TEMPLATE  = {{ read_file("src/styles.css") }}.gsub('\u00A0', ' ')   # remove possible bad spaces

# Embed favicon assets at compile time. These must exist during compile.
FAVICON_PNG = {{ read_file "public/favicon.png" }}.to_slice
FAVICON_SVG = {{ read_file "public/favicon.svg" }}.to_slice
FAVICON_ICO = {{ read_file "public/favicon.ico" }}.to_slice

def serve_bytes(ctx : HTTP::Server::Context, bytes : Bytes, content_type : String)
  ctx.response.content_type = content_type
  ctx.response.headers["Cache-Control"] = "public, max-age=31536000"
  ctx.response.output.write bytes
end

# ----- Config related -----

DEFAULT_CONFIG_CANDIDATES = [
  "feeds.yml",
  "config/feeds.yml",
  "feeds.yaml",
  "config/feeds.yaml",
]

struct Feed
  include YAML::Serializable

  property title : String
  property url : String
  property header_color : String?
end

struct Config
  include YAML::Serializable

  # Global refresh interval in minutes (default: 10)
  property refresh_minutes : Int32 = 10

  # Page title (optional, default: Quick Headlines)
  property page_title : String = "Quick Headlines"

  # Feed Item Limit (optional, default: 10)
  property item_limit : Int32 = 10

  # Wev Server Port (optional, default: 3030)
  property server_port : Int32 = 3030

  property feeds : Array(Feed)
end

record ConfigState, config : Config, mtime : Time

def file_mtime(path : String) : Time
  File.info(path).modification_time
end

def load_config(path : String) : Config
  File.open(path) do |io|
    Config.from_yaml(io)
  end
end

def find_default_config : String?
  DEFAULT_CONFIG_CANDIDATES.find { |path| File.exists?(path) }
end

def parse_config_arg(args : Array(String)) : String?
  if arg = args.find(&.starts_with?("config="))
    return arg.split("=", 2)[1]
  end

  if args.size >= 1 && !args[0].includes?("=")
    return args[0]
  end

  nil
end

# ----- In-memory state -----

record Item, title : String, link : String, pub_date : Time?
record FeedData, title : String, url : String, site_link : String, header_color : String?, items : Array(Item), etag : String? = nil, last_modified : String? = nil, favicon : String? = nil do
  def display_header_color
    (header_color.try(&.strip).presence) || "transparent"
  end

  def display_link
    site_link.empty? ? url : site_link
  end
end

class AppState
  property feeds = [] of FeedData
  property updated_at = Time.local
  property config_title = "Quick Headlines"

  def update(feeds : Array(FeedData), updated_at : Time)
    @feeds = feeds
    @updated_at = updated_at
  end
end

STATE = AppState.new

# ----- HTTP client pooling and concurrency control -----

class ClientPool
  def initialize
    @clients = {} of String => HTTP::Client
  end

  def for(url : String) : HTTP::Client
    uri = URI.parse(url)
    key = "#{uri.scheme}://#{uri.host}:#{uri.port || (uri.scheme == "https" ? 443 : 80)}"
    @clients[key]? || begin
      client = HTTP::Client.new(uri)
      client.read_timeout = 15.seconds
      client.connect_timeout = 10.seconds
      @clients[key] = client
    end
  end
end

POOL = ClientPool.new

# Limit concurrent fetches (helps smooth peak allocations)
# Adjust capacity to your environment (5–10 is a good start).
CONCURRENCY = 8
SEM         = Channel(Nil).new(CONCURRENCY).tap { |channel| CONCURRENCY.times { channel.send(nil) } }

# ----- Fetch and render -----

def parse_time(str : String?) : Time?
  return unless str

  [
    Time::Format::RFC_2822,
    Time::Format::RFC_3339,
    Time::Format::ISO_8601_DATE_TIME,
    Time::Format::ISO_8601_DATE,
  ].each do |format|
    begin
      return format.parse(str)
    rescue
    end
  end
  nil
end

def relative_time(t : Time?) : String
  return "" unless t
  minutes = [(Time.utc - t.to_utc).total_minutes, 0.0].max

  if minutes < 60
    "#{minutes.to_i}m"
  elsif minutes < 1440
    "#{(minutes / 60).to_i}h"
  else
    "#{(minutes / 1440).to_i}d"
  end
end

def parse_feed(io : IO, limit : Int32) : {site_link: String, items: Array(Item), favicon: String?}
  xml = XML.parse(io)
  rss = parse_rss(xml, limit)
  return rss unless rss[:items].empty?
  atom = parse_atom(xml, limit)
  return atom unless atom[:items].empty?
  {site_link: "#", items: [] of Item, favicon: nil}
rescue
  {site_link: "#", items: [] of Item, favicon: nil}
end

private def parse_rss(xml : XML::Node, limit : Int32) : {site_link: String, items: Array(Item), favicon: String?}
  site_link = "#"
  items = [] of Item
  if channel = xml.xpath_node("//channel")
    site_link = channel.xpath_node("./link").try(&.text) || site_link
    channel.xpath_nodes("./item").each do |node|
      title = node.xpath_node("./title").try(&.text).try { |text| HTML.unescape(text) } || "Untitled"
      link = node.xpath_node("./link").try(&.text) || "#"
      pub_date = parse_time(node.xpath_node("./pubDate").try(&.text))
      items << Item.new(title, link, pub_date)
      break if items.size >= limit
    end
  end
  favicon = xml.xpath_node("//channel/image/url").try(&.text)
  {site_link: site_link, items: items, favicon: favicon}
end

private def parse_atom_entry(node : XML::Node) : Item
  # Title text
  title = node.xpath_node("./*[local-name()='title']").try(&.text).try(&.strip)
  title = HTML.unescape(title) if title
  title = "Untitled" if title.nil? || title.empty?

  # Entry link preference: rel="alternate" (type text/html) -> any link with href -> text content
  link_node = node.xpath_node("./*[local-name()='link'][@rel='alternate' and (not(@type) or starts-with(@type,'text/html'))]") ||
              node.xpath_node("./*[local-name()='link'][@rel='alternate']") ||
              node.xpath_node("./*[local-name()='link'][@href]") ||
              node.xpath_node("./*[local-name()='link']")
  link = link_node.try(&.[]?("href")) || link_node.try(&.text).try(&.strip) || "#"

  published_str = node.xpath_node("./*[local-name()='published']").try(&.text) ||
                  node.xpath_node("./*[local-name()='updated']").try(&.text)
  pub_date = parse_time(published_str)

  Item.new(title, link, pub_date)
end

private def parse_atom(xml : XML::Node, limit : Int32) : {site_link: String, items: Array(Item), favicon: String?}
  site_link = "#"
  items = [] of Item

  # FIX: correct XPath string
  feed_node = xml.xpath_node("//*[local-name()='feed']")
  return {site_link: site_link, items: items, favicon: nil} unless feed_node

  # Site link preference: rel="alternate" (type text/html) -> first link with href -> keep default
  alt = feed_node.xpath_node("./*[local-name()='link'][@rel='alternate' and (not(@type) or starts-with(@type,'text/html'))]") ||
        feed_node.xpath_node("./*[local-name()='link'][@rel='alternate']") ||
        feed_node.xpath_node("./*[local-name()='link'][@href]")
  site_link = alt.try(&.[]?("href")) || alt.try(&.text).try(&.strip) || site_link

  # Entries
  feed_node.xpath_nodes("./*[local-name()='entry']").each do |node|
    items << parse_atom_entry(node)
    break if items.size >= limit
  end

  favicon = feed_node.xpath_node("./*[local-name()='icon']").try(&.text) ||
            feed_node.xpath_node("./*[local-name()='logo']").try(&.text)
  {site_link: site_link, items: items, favicon: favicon}
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
    favicon = parsed[:favicon]

    if favicon.nil?
      begin
        if host = URI.parse(site_link).host
          favicon = "https://www.google.com/s2/favicons?domain=#{host}&sz=32"
        end
      rescue
      end
    end

    # Capture caching headers
    etag = response.headers["ETag"]?
    last_modified = response.headers["Last-Modified"]?

    if items.empty?
      # Show a single placeholder item linking to the feed itself
      items = [Item.new("No items found (or unsupported format)", feed.url, nil)]
    end
    FeedData.new(feed.title, feed.url, site_link, feed.header_color, items, etag, last_modified, favicon)
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

# Builds the inner HTML for all feed boxes as link lists.
def render_feed_boxes(io : IO)
  feeds = STATE.feeds

  # Emit into the same IO variable name "io"
  Slang.embed("src/feed_boxes.slang", "io")
end

def render_page(io : IO)
  title = STATE.config_title
  css = CSS_TEMPLATE
  updated_at = STATE.updated_at.to_s
  feeds = STATE.feeds

  Slang.embed("src/layout.slang", "io")
end

def refresh_all(config : Config)
  STATE.config_title = config.page_title

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

# ----- Background refresh fiber -----

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

# ----- HTTP server -----

def start_server(port : Int32)
  server = HTTP::Server.new do |context|
    case {context.request.method, context.request.path}
    when {"GET", "/version"}
      context.response.content_type = "text/plain; charset=utf-8"
      # Use updated_at as a change token
      context.response.print STATE.updated_at.to_unix_ms
    when {"GET", "/feeds"}
      context.response.content_type = "text/html; charset=utf-8"
      render_feed_boxes(context.response)
    when {"GET", "/favicon.png"}
      serve_bytes(context, FAVICON_PNG, "image/png")
    when {"GET", "/favicon.svg"}
      serve_bytes(context, FAVICON_SVG, "image/svg+xml")
    when {"GET", "/favicon.ico"}
      serve_bytes(context, FAVICON_ICO, "image/x-icon")
    else
      context.response.content_type = "text/html; charset=utf-8"
      render_page(context.response)
    end
  end

  server.bind_tcp "0.0.0.0", port
  puts "Listening on http://0.0.0.0:#{port}/ "
  server.listen
end

# Small helper to stream a file with proper content type and 404 on miss
def send_static(ctx : HTTP::Server::Context, path : String, content_type : String)
  if File.exists?(path)
    ctx.response.content_type = content_type
    File.open(path) do |file|
      IO.copy(file, ctx.response)
    end
  else
    ctx.response.status_code = 404
    ctx.response.content_type = "text/plain; charset=utf-8"
    ctx.response.print "Not found: #{path}"
  end
end

# ----- main -----

# Try to get config path from a named argument (config=...), or positional, or fall back to defaults
config_path = parse_config_arg(ARGV) || find_default_config

unless config_path && File.exists?(config_path)
  STDERR.puts "Config not found."
  STDERR.puts "Provide via: config=PATH or positional PATH, or place feeds.yml in one of:"
  DEFAULT_CONFIG_CANDIDATES.each { |path| STDERR.puts "  - #{path}" }
  exit 1
end

initial_config = load_config(config_path)
state = ConfigState.new(initial_config, file_mtime(config_path))

# Initial load so the first request sees real data
refresh_all(state.config)

# Start periodic refresh
start_refresh_loop(config_path)

# Serve in-memory HTML
start_server(state.config.server_port)
