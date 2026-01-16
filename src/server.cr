require "http/server"
require "slang"

# Require local dependencies that are used in this file
require "./config"
require "./fetcher"
require "./models"
require "./storage"
require "./utils"
require "./favicon_storage"
require "./minhash"

# ----- Compile-time embedded templates -----

{% if env("APP_ENV") == "production" %}
  {% if file_exists?(__DIR__ + "/../assets/css/production.css") %}
    CSS_TEMPLATE = {{ read_file(__DIR__ + "/../assets/css/production.css") }}.gsub('\u00A0', ' ')
  {% else %}
    {{ raise "Production CSS missing! Run 'make css' before building." }}
  {% end %}
  IS_DEVELOPMENT = false
{% else %}
  {% if file_exists?(__DIR__ + "/../assets/css/development.css") %}
    CSS_TEMPLATE = {{ read_file(__DIR__ + "/../assets/css/development.css") }}.gsub('\u00A0', ' ')
  {% else %}
    {{ raise "Development CSS missing! Run 'make css-dev' before building." }}
  {% end %}
  IS_DEVELOPMENT = true
{% end %}

# Embed favicon assets at compile time. These must exist during compile.
FAVICON_PNG = {{ read_file(__DIR__ + "/../assets/images/favicon.png") }}.to_slice
FAVICON_SVG = {{ read_file(__DIR__ + "/../assets/images/favicon.svg") }}.to_slice
FAVICON_ICO = {{ read_file(__DIR__ + "/../assets/images/favicon.ico") }}.to_slice

def serve_bytes(ctx : HTTP::Server::Context, bytes : Bytes, content_type : String)
  ctx.response.content_type = content_type
  ctx.response.headers["Cache-Control"] = "public, max-age=31536000"
  ctx.response.output.write bytes
end

# Builds the inner HTML for all feed boxes as link lists.
def render_feed_boxes(io : IO, active_tab : String? = nil)
  # Filter content based on the active tab
  feeds = active_tab ? STATE.feeds_for_tab(active_tab) : STATE.feeds                   # ameba:disable Lint/UselessAssign
  releases = active_tab ? STATE.releases_for_tab(active_tab) : STATE.software_releases # ameba:disable Lint/UselessAssign

  # total_item_count is nil for initial render, set for load more
  # ameba:disable Lint/UselessAssign
  total_item_count = nil

  # Emit into the same IO variable name "io"
  Slang.embed("src/feed_boxes.slang", "io")
end

def render_page(io : IO, active_tab : String = "all")
  title = STATE.config_title # ameba:disable Lint/UselessAssign
  css = CSS_TEMPLATE
  updated_at = STATE.updated_at.to_utc.to_s("%Y-%m-%dT%H:%M:%S%z") # ameba:disable Lint/UselessAssign
  tabs = STATE.tabs                                                # ameba:disable Lint/UselessAssign

  Slang.embed("src/layout.slang", "io")
end

def handle_feed_more(context : HTTP::Server::Context)
  url = context.request.query_params["url"]?
  limit = context.request.query_params["limit"]?.try(&.to_i?) || 20
  offset = context.request.query_params["offset"]?.try(&.to_i?) || 0

  if url && (config = STATE.config)
    # Search top-level feeds and all feeds within tabs
    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)

    if feed_config = all_feeds.find { |feed| feed.url == url }
      cache = FeedCache.instance

      # 1. Check if we have enough data in the cache to fulfill the request
      # We count the items currently stored for this URL.
      # Note: This is a rough check; if we have 100 items but they are old, we still show them.
      # To support "infinite scroll" effectively, we ensure the DB has at least (offset + limit) items.
      current_count = 0
      if cached_feed = cache.get(url)
        current_count = cached_feed.items.size
      end

      needed_count = offset + limit

      # 2. If cache is shallow, fetch a larger batch to populate it
      # We fetch a buffer (e.g., +50) to avoid hitting the network on every single click.
      # We pass 'nil' for previous_data to force a fresh parse and skip ETag checks,
      # ensuring we dig deep into the history.
      if current_count < needed_count
        fetch_feed(feed_config, needed_count + 50, nil)
      end

      # 3. Retrieve ALL items from the cache (not just a slice)
      # This ensures morphdom gets the complete feed with all items
      if data = cache.get(url)
        # Only include items up to offset + limit, but don't exceed available items
        max_index = Math.min(offset + limit, data.items.size)
        trimmed_items = data.items[0...max_index]

        # Create a new FeedData with trimmed items
        full_data = FeedData.new(
          data.title,
          data.url,
          data.site_link,
          data.header_color,
          trimmed_items,
          data.etag,
          data.last_modified,
          data.favicon,
          data.favicon_data
        )

        context.response.content_type = "text/html; charset=utf-8"

        # Set render_full to false so the template returns only list items
        # ameba:disable Lint/UselessAssign
        render_full = false
        feeds = [full_data]       # ameba:disable Lint/UselessAssign
        releases = [] of FeedData # ameba:disable Lint/UselessAssign
        # Pass cumulative count for the Load More button
        # ameba:disable Lint/UselessAssign
        total_item_count = trimmed_items.size
        Slang.embed("src/feed_boxes.slang", "context.response")
      else
        context.response.content_type = "text/plain; charset=utf-8"
        context.response.status_code = 500
        context.response.print "Error retrieving feed slice"
      end
    else
      context.response.status_code = 404
    end
  else
    context.response.status_code = 400
  end
end

def handle_proxy_image(context : HTTP::Server::Context)
  if url = context.request.query_params["url"]?
    begin
      current_url = url
      redirects = 0
      success = false

      loop do
        loop_uri = URI.parse(current_url)
        loop_client = create_client(current_url)
        loop_headers = HTTP::Headers{
          "User-Agent"      => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Accept-Language" => "en-US,en;q=0.9",
          "Connection"      => "keep-alive",
        }

        context.response.status_code = 502 if redirects > 10
        break if redirects > 10

        begin
          loop_client.get(loop_uri.request_target, headers: loop_headers) do |response|
            if response.status.redirection? && (location = response.headers["Location"]?)
              current_url = loop_uri.resolve(location).to_s
              redirects += 1
            elsif response.status.success?
              context.response.content_type = response.content_type || "image/png"
              context.response.headers["Access-Control-Allow-Origin"] = "*"
              context.response.headers["Cache-Control"] = "public, max-age=86400"
              IO.copy(response.body_io, context.response)
              success = true
            else
              context.response.status_code = response.status_code
              success = true
            end
          end
        end
        break if success
      end
    rescue
      context.response.status_code = 404
    end
  else
    context.response.status_code = 400
  end
end

def handle_version(context : HTTP::Server::Context)
  context.response.content_type = "text/plain; charset=utf-8"
  # Use updated_at as a change token
  context.response.print STATE.updated_at.to_unix_ms
end

def get_active_tab(context : HTTP::Server::Context) : String
  context.request.query_params["tab"]? || STATE.tabs.first?.try(&.name) || "all"
end

def handle_feeds(context : HTTP::Server::Context)
  active_tab = get_active_tab(context)
  context.response.content_type = "text/html; charset=utf-8"
  render_feed_boxes(context.response, active_tab)
end

def handle_root(context : HTTP::Server::Context)
  active_tab = get_active_tab(context)
  context.response.content_type = "text/html; charset=utf-8"
  render_page(context.response, active_tab)
end

def handle_timeline_items(context : HTTP::Server::Context)
  limit = context.request.query_params["limit"]?.try(&.to_i?) || 100
  offset = context.request.query_params["offset"]?.try(&.to_i?) || 0
  last_day = context.request.query_params["last_day"]? # ameba:disable Lint/UselessAssign

  # Get all timeline items and apply pagination
  all_items = STATE.all_timeline_items
  total_count = all_items.size

  max_index = Math.min(offset + limit, total_count)
  raw_items = all_items[offset...max_index]

  # Convert to clustered items with cluster information
  # ameba:disable Lint/UselessAssign
  timeline_items = raw_items.map do |item|
    add_cluster_info(item)
  end

  context.response.content_type = "text/html; charset=utf-8"

  # Render only the timeline items (no container, no sentinel) for infinite scroll
  Slang.embed("src/timeline_items.slang", "context.response")
end

def handle_timeline(context : HTTP::Server::Context)
  title = STATE.config_title # ameba:disable Lint/UselessAssign
  css = CSS_TEMPLATE
  updated_at = STATE.updated_at.to_utc.to_s("%Y-%m-%dT%H:%M:%S%z") # ameba:disable Lint/UselessAssign

  # Get all timeline items and filter to show only one day by default
  all_items = STATE.all_timeline_items

  # Find items from the first day
  if all_items.size > 0 && (first_item_date = all_items[0].item.pub_date)
    first_day = first_item_date.to_local.to_s("%Y-%m-%d")

    # Filter items to only show the first day
    one_day_items = all_items.select do |item|
      item_date = item.item.pub_date
      item_date && item_date.to_local.to_s("%Y-%m-%d") == first_day
    end

    # Convert to clustered items
    # ameba:disable Lint/UselessAssign
    timeline_items = one_day_items.map { |item| add_cluster_info(item) }

    has_more = all_items.size > one_day_items.size # ameba:disable Lint/UselessAssign
    next_offset = one_day_items.size               # ameba:disable Lint/UselessAssign
  else
    raw_items = all_items[0...100]
    # ameba:disable Lint/UselessAssign
    timeline_items = raw_items.map { |item| add_cluster_info(item) }
    has_more = all_items.size > 100 # ameba:disable Lint/UselessAssign
    next_offset = 100               # ameba:disable Lint/UselessAssign
  end

  # Pre-render the timeline content
  timeline_html = String.build do |_fh_io|
    Slang.embed("src/timeline.slang", "_fh_io")
  end

  context.response.content_type = "text/html; charset=utf-8"

  # Pass timeline_html as a variable to the template
  # ameba:disable Lint/UselessAssign
  rendered_timeline = timeline_html

  Slang.embed("src/timeline_page.slang", "context.response")
end

# Helper function to add cluster information to a timeline item
def add_cluster_info(item : TimelineItem) : ClusteredTimelineItem
  cache = FeedCache.instance

  # Get item_id from database
  item_id = cache.get_item_id(item.feed_url, item.item.link)

  if item_id
    cluster_id = cache.db.query_one?("SELECT cluster_id FROM items WHERE id = ?", item_id, as: {Int64?})
    cluster_size = cache.get_cluster_size(item_id)
    is_representative = cache.cluster_representative?(item_id)

    ClusteredTimelineItem.new(
      item.item,
      item.feed_title,
      item.feed_url,
      item.feed_link,
      item.favicon,
      item.favicon_data,
      item.header_color,
      cluster_id,
      is_representative,
      cluster_size > 1 ? cluster_size : nil
    )
  else
    # No cluster info available, return item as-is with defaults
    ClusteredTimelineItem.new(
      item.item,
      item.feed_title,
      item.feed_url,
      item.feed_link,
      item.favicon,
      item.favicon_data,
      item.header_color,
      nil,
      true,
      nil
    )
  end
end

def handle_favicon(context : HTTP::Server::Context, path : String)
  # Extract filename from path
  filename = path.lstrip("/favicons/")
  filepath = File.join(FaviconStorage::FAVICON_DIR, filename)

  if File.exists?(filepath)
    # Determine content type based on extension
    ext = File.extname(filename).lstrip('.')
    content_type = case ext.downcase
                   when "png"         then "image/png"
                   when "jpg", "jpeg" then "image/jpeg"
                   when "ico"         then "image/x-icon"
                   when "svg"         then "image/svg+xml"
                   when "webp"        then "image/webp"
                   else                    "image/png"
                   end

    context.response.content_type = content_type
    context.response.headers["Cache-Control"] = "public, max-age=31536000"
    File.open(filepath) do |file|
      IO.copy(file, context.response)
    end
  else
    context.response.status_code = 404
    context.response.content_type = "text/plain; charset=utf-8"
    context.response.print "Favicon not found"
  end
end

def start_server(port : Int32)
  server = HTTP::Server.new do |context|
    path = context.request.path

    case {context.request.method, path}
    when {"GET", "/version"}
      handle_version(context)
    when {"GET", "/feeds"}
      handle_feeds(context)
    when {"GET", "/feed_more"}
      handle_feed_more(context)
    when {"GET", "/timeline"}
      handle_timeline(context)
    when {"GET", "/timeline_items"}
      handle_timeline_items(context)
    when {"GET", "/favicon.png"}
      serve_bytes(context, FAVICON_PNG, "image/png")
    when {"GET", "/favicon.svg"}
      serve_bytes(context, FAVICON_SVG, "image/svg+xml")
    when {"GET", "/favicon.ico"}
      serve_bytes(context, FAVICON_ICO, "image/x-icon")
    when {"GET", "/proxy_image"}
      handle_proxy_image(context)
    when {"GET", "/"}
      handle_root(context)
    else
      if path.starts_with?("/favicons/")
        handle_favicon(context, path)
      else
        context.response.status_code = 404
        context.response.print "404 Not Found"
      end
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
