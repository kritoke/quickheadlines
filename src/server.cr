require "http/server"
require "slang"

# Require local dependencies that are used in this file
require "./config"
require "./fetcher"
require "./models"
require "./storage"
require "./utils"

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

  # Emit into the same IO variable name "io"
  Slang.embed("src/feed_boxes.slang", "io")
end

def render_page(io : IO, active_tab : String = "all")
  title = STATE.config_title # ameba:disable Lint/UselessAssign
  css = CSS_TEMPLATE
  updated_at = STATE.updated_at.to_utc.to_s("%Y-%m-%dT%H:%M:%S%z") # ameba:disable Lint/UselessAssign
  tabs = STATE.tabs                                                # ameba:disable Lint/UselessAssign
  is_development = IS_DEVELOPMENT                                  # ameba:disable Lint/UselessAssign

  Slang.embed("src/layout.slang", "io")
end

def handle_feed_more(context : HTTP::Server::Context)
  url = context.request.query_params["url"]?
  limit = context.request.query_params["limit"]?.try(&.to_i?) || 20

  if url && (config = STATE.config)
    # Search top-level feeds and all feeds within tabs
    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)

    if feed_config = all_feeds.find { |feed| feed.url == url }
      # Force fetch with new limit (pass nil for previous_data to avoid 304 and force re-parse)
      data = fetch_feed(feed_config, limit, nil)
      
      # Check if fetch returned valid data to prevent crashing
      if data
        context.response.content_type = "text/html; charset=utf-8"
        feeds = [data]            # ameba:disable Lint/UselessAssign
        releases = [] of FeedData # ameba:disable Lint/UselessAssign
        Slang.embed("src/feed_boxes.slang", "context.response")
      else
        context.response.content_type = "text/plain; charset=utf-8"
        context.response.status_code = 500
        context.response.print "Error fetching feed data"
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

def start_server(port : Int32)
  server = HTTP::Server.new do |context|
    case {context.request.method, context.request.path}
    when {"GET", "/version"}
      handle_version(context)
    when {"GET", "/feeds"}
      handle_feeds(context)
    when {"GET", "/feed_more"}
      handle_feed_more(context)
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
      context.response.status_code = 404
      context.response.print "404 Not Found"
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
