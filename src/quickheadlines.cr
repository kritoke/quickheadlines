require "yaml"
require "http/server"
require "http/client"
require "xml"
require "slang"
require "html"
require "gc"

# ----- Compile-time embedded templates -----

# These files must exist at compile time in the src directory
LAYOUT_SOURCE = {{ read_file("src/layout.slang") }}.gsub('\u00A0', ' ') # remove possible bad spaces
CSS_TEMPLATE  = {{ read_file("src/styles.css") }}.gsub('\u00A0', ' ')   # remove possible bad spaces
FAVICON_PNG = {{ read_file "public/favicon.png" }}
FAVICON_SVG = {{ read_file "public/favicon.svg" }}
FAVICON_ICO = {{ read_file "public/favicon.ico" }}

def serve_bytes(ctx : HTTP::Server::Context, bytes : Bytes, content_type : String)
  ctx.response.content_type = content_type
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

record Item, title : String, link : String
record FeedData, title : String, url : String, site_link : String, header_color : String?, items : Array(Item)

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

# ----- Fetch and render -----

# Keep the same return type
def parse_feed(io : IO) : {site_link: String, items: Array(Item)}
  xml = XML.parse(io)

  rss = parse_rss(xml)
  return rss unless rss[:items].empty?

  atom = parse_atom(xml)
  return atom unless atom[:items].empty?

  {site_link: "#", items: [] of Item}
rescue ex : Exception
  {site_link: "#", items: [] of Item}
end

private def parse_rss(xml : XML::Node) : {site_link: String, items: Array(Item)}
  site_link = "#"
  items = [] of Item

  if channel = xml.xpath_node("//channel")
    site_link = channel.xpath_node("./link").try(&.text) || site_link
    channel.xpath_nodes("./item").each do |node|
      title = node.xpath_node("./title").try(&.text) || "Untitled"
      link = node.xpath_node("./link").try(&.text) || "#"
      items << Item.new(title, link)
    end
  end

  {site_link: site_link, items: items}
end

private def parse_atom(xml : XML::Node) : {site_link: String, items: Array(Item)}
  site_link = "#"
  items = [] of Item

  feed_node = xml.xpath_node("//*[local-name()='feed']")
  return {site_link: site_link, items: items} unless feed_node

  alt = feed_node.xpath_node("./*[local-name()='link'][@rel='alternate']")
  site_link = alt.try(&.[]?("href")) ||
              feed_node.xpath_node("./*[local-name()='link']").try(&.[]?("href")) ||
              site_link

  feed_node.xpath_nodes("./*[local-name()='entry']").each do |node|
    title = node.xpath_node("./*[local-name()='title']").try(&.text) || "Untitled"
    link_node = node.xpath_node("./*[local-name()='link'][@rel='alternate' or not(@rel)]")
    link = link_node.try(&.[]?("href")) || "#"
    items << Item.new(title, link)
  end

  {site_link: site_link, items: items}
end

def fetch_feed(feed : Feed) : FeedData
  HTTP::Client.get(feed.url) do |response|
    unless response.status.success?
      # Fall back to an error message in the body box
      return FeedData.new(
        feed.title,
        feed.url,
        feed.url,
        feed.header_color,
        [Item.new("Error fetching feed (status #{response.status_code})", feed.url)],
      )
    end

    parsed = parse_feed(response.body_io)
    items = parsed[:items]
    site_link = parsed[:site_link] || feed.url

    if items.empty?
      # Show a single placeholder item linking to the feed itself
      items = [Item.new("No items found (or unsupported format)", feed.url)]
    end
    FeedData.new(feed.title, feed.url, site_link, feed.header_color, items)
  end
end

# Builds the inner HTML for all feed boxes as link lists.
def render_feed_boxes(io : IO)
    feeds = STATE.feeds

    # Emit into the same IO variable name "io"
    Slang.embed("#{__DIR__}/feed_boxes.slang", "io")
end

def render_page(io : IO)
    title      = STATE.config_title
    css        = CSS_TEMPLATE
    updated_at = STATE.updated_at.to_s
    feeds = STATE.feeds

    Slang.embed("#{__DIR__}/layout.slang", "io")
end

def refresh_all(config : Config)
  STATE.config_title = config.page_title

  new_feeds = config.feeds.map do |feed|
    data = fetch_feed(feed)
    FeedData.new(data.title, data.url, data.site_link, data.header_color, data.items.first(config.item_limit))
  end

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
    when {"GET", "/favicon.png"}
      serve_bytes(context, FAVICON_PNG.to_slice, "image/png")
    when {"GET", "/favicon.svg"}
      serve_bytes(context, FAVICON_SVG.to_slice, "image/svg+xml")
    when {"GET", "/favicon.ico"}
      serve_bytes(context, FAVICON_ICO.to_slice, "image/x-icon")
    else
      context.response.content_type = "text/html; charset=utf-8"
      render_page(context.response)
    end
  end

  address = server.bind_tcp "0.0.0.0", port
  puts "Listening on http://#{address}:#{port}/ "
  server.listen
end

# Small helper to stream a file with proper content type and 404 on miss
def send_static(ctx : HTTP::Server::Context, path : String, content_type : String)
  if File.exists?(path)
    ctx.response.content_type = content_type
    File.open(path) { |f| IO.copy(f, ctx.response) }
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
