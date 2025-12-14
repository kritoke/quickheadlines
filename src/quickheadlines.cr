require "yaml"
require "http/server"
require "http/client"
require "xml"

# ----- Compile-time embedded templates -----

# These files must exist at compile time in the src directory
HTML_TEMPLATE = {{ read_file("src/layout.html") }}
CSS_TEMPLATE  = {{ read_file("src/styles.css") }}

# ----- Config types -----

struct Feed
  include YAML::Serializable

  property title : String
  property url : String
end

struct Config
  include YAML::Serializable

  # Global refresh interval in minutes (default: 10)
  property refresh_minutes : Int32 = 10

  # Page title (optional, default: Quick Headlines)
  property page_title : String = "Quick Headlines"

  # Feed Item Limit (optional, default: 10)
  property item_limit : Int32 = 10

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

# ----- In-memory state -----

record Item, title : String, link : String
record FeedData, title : String, url : String, site_link : String, items : Array(Item)

class AppState
  getter feeds = [] of FeedData
  getter! html : String
  getter! updated_at : Time

  def initialize
    @feeds = [] of FeedData
    @html = "<html><body><p>Loading…</p></body></html>"
    @updated_at = Time.local
  end

  def update(feeds : Array(FeedData), html : String, updated_at : Time)
    @feeds = feeds
    @html = html
    @updated_at = updated_at
  end
end

STATE = AppState.new

# ----- Fetch and render -----

def parse_feed(xml_str : String) : {site_link: String, items: Array(Item)}
  items = [] of Item
  site_link = "#"

  xml = XML.parse(xml_str)

  # Handle RSS 2.0: <rss><channel><item>...</item></channel></rss>
  if channel = xml.xpath_node("//channel")
    site_link = channel.xpath_node("./link").try(&.text) || site_link
    channel.xpath_nodes("./item").each do |node|
      title = node.xpath_node("./title").try(&.text) || "Untitled"
      link = node.xpath_node("./link").try(&.text) || "#"
      items << Item.new(title, link)
    end
  end

  # Atom (namespace-agnostic) fallback
  if items.empty?
    feed_node = xml.xpath_node("//*[local-name()='feed']")
    if feed_node
      # Prefer rel='alternate', else first link's href
      alt = feed_node.xpath_node("./*[local-name()='link'][@rel='alternate']")
      site_link = alt.try { |n| n["href"]? } ||
                  feed_node.xpath_node("./*[local-name()='link']").try { |n| n["href"]? } ||
                  site_link

      # We use local-name()='entry' to find <entry> tags regardless of xmlns="..."
      feed_node.xpath_nodes("./*[local-name()='entry']").each do |node|
        title = node.xpath_node("./*[local-name()='title']").try(&.text) || "Untitled"
        # We look for a link tag where rel='alternate' OR where rel is missing (default)
        link_node = node.xpath_node("./*[local-name()='link'][@rel='alternate' or not(@rel)]")
        link = link_node.try { |ln| ln["href"]? } || "#"
        items << Item.new(title, link)
      end
    end
  end

  {site_link: site_link, items: items}
rescue
  {site_link: "#", items: [] of Item}
end

def fetch_feed(feed : Feed) : FeedData
  response = HTTP::Client.get(feed.url)
  unless response.status.success?
    # Fall back to an error message in the body box
    return FeedData.new(
      feed.title,
      feed.url,
      feed.url,
      [Item.new("Error fetching feed (status #{response.status_code})", feed.url)],
    )
  end

  parsed = parse_feed(response.body)
  items = parsed[:items]
  site_link = parsed[:site_link] || feed.url

  if items.empty?
    # Show a single placeholder item linking to the feed itself
    items = [Item.new("No items found (or unsupported format)", feed.url)]
  end
  FeedData.new(feed.title, feed.url, site_link, items)
end

# Builds the inner HTML for all feed boxes as link lists.
def render_feed_boxes(feeds : Array(FeedData)) : String
  String.build do |io|
    feeds.each do |feed|
      io << "<article class=\"feed-box rounded-xl border border-border.light bg-card.light shadow-sm p-4
                 dark:bg-card dark:border-border.subtle\">\n"

      site_href = HTML.escape(feed.site_link.empty? ? feed.url : feed.site_link)
      feed_title = HTML.escape(feed.title)
      io << "  <h2 class=\"text-sm md:text-base font-semibold mb-2 leading-snug\"><a href=\"#{site_href}\" target=\"_blank\" rel=\"noopener noreferrer\">#{feed_title}</a></h2>\n"

      io << "    <ul class=\"space-y-1 leading-relaxed\">\n"
      feed.items.each do |item|
        # Escape title, and safely include link
        title = HTML.escape(item.title)
        link = HTML.escape(item.link)
        io << "    <li><a  class=\"text-sm md:text-[0.95rem] text-sky-700 hover:text-sky-800 underline underline-offset-2
dark:text-sky-400 dark:hover:text-sky-300 break-words\" href=\"#{link}\" target=\"_blank\" rel=\"noopener noreferrer\">#{title}</a></li>\n"
      end
      io << "  </ul>\n"
      io << "</article>\n"
    end
  end
end

# Applies template placeholders in the embedded layout.
def apply_template(
  page_title : String,
  inner_html : String,
  updated_at : Time,
) : String
  html = HTML_TEMPLATE
    .gsub("{{ TITLE }}", page_title)
    .gsub("{{ CSS }}", CSS_TEMPLATE)
    .gsub("{{ CONTENT }}", inner_html)
    .gsub("{{ UPDATED_AT }}", updated_at.to_s)

  html
end

def refresh_all(config : Config)
  feeds = config.feeds.map { |f| fetch_feed(f) }

  limited_feeds = feeds.map do |feed|
    FeedData.new(feed.title, feed.url, feed.site_link, feed.items.first(config.item_limit))
  end

  boxes = render_feed_boxes(limited_feeds)
  now = Time.local
  html = apply_template(config.page_title, boxes, now)

  STATE.update(limited_feeds, html, now)
end

# ----- Background refresh fiber -----

def start_refresh_loop(config_path : String, state : ConfigState)
  spawn do
    current = state
    loop do
      begin
        # Check if config file changed
        begin
          mtime = file_mtime(config_path)
          if mtime > current.mtime
            new_config = load_config(config_path)
            current = ConfigState.new(new_config, mtime)
            puts "[#{Time.local}] Reloaded config from #{config_path}"
          end
        rescue err
          # If the file temporarily unreadable, log and continue using last good config
          puts "Error checking/reloading config: #{err.message}"
        end

        # Refresh feeds using current config
        refresh_all(current.config)
        puts "[#{Time.local}] Refreshed feeds"
      rescue err
        puts "Error refreshing feeds: #{err.message}"
      end

      # Sleep based on current config's interval
      sleep (current.config.refresh_minutes * 60).seconds
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
    else
      context.response.content_type = "text/html; charset=utf-8"
      context.response.print STATE.html
    end
  end

  address = server.bind_tcp port
  puts "Listening on http://#{address}"
  server.listen
end

# ----- main -----

if ARGV.size < 1
  puts "Usage: #{PROGRAM_NAME} CONFIG_YAML"
  exit 1
end

config_path = ARGV[0]
initial_config = load_config(config_path)
state = ConfigState.new(initial_config, file_mtime(config_path))

# Initial load so the first request sees real data
refresh_all(state.config)

# Start periodic refresh
start_refresh_loop(config_path, state)

# Serve in-memory HTML
start_server(8080)
