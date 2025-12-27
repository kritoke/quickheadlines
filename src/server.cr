require "http/server"
require "slang"

# ----- Compile-time embedded templates -----

{% if env("APP_ENV") == "production" %}
  CSS_TEMPLATE = {{ read_file("assets/css/production.css") }}.gsub('\u00A0', ' ')
  IS_DEVELOPMENT = false
{% else %}
  CSS_TEMPLATE = {{ read_file("assets/css/development.css") }}.gsub('\u00A0', ' ')
  IS_DEVELOPMENT = true
{% end %}

# Embed favicon assets at compile time. These must exist during compile.
FAVICON_PNG = {{ read_file "assets/images/favicon.png" }}.to_slice
FAVICON_SVG = {{ read_file "assets/images/favicon.svg" }}.to_slice
FAVICON_ICO = {{ read_file "assets/images/favicon.ico" }}.to_slice

def serve_bytes(ctx : HTTP::Server::Context, bytes : Bytes, content_type : String)
  ctx.response.content_type = content_type
  ctx.response.headers["Cache-Control"] = "public, max-age=31536000"
  ctx.response.output.write bytes
end

# Builds the inner HTML for all feed boxes as link lists.
def render_feed_boxes(io : IO, active_tab : String? = nil)
  # Filter content based on the active tab
  feeds = active_tab ? STATE.feeds_for_tab(active_tab) : STATE.feeds
  releases = active_tab ? STATE.releases_for_tab(active_tab) : STATE.software_releases

  # Emit into the same IO variable name "io"
  Slang.embed("src/feed_boxes.slang", "io")
end

def render_page(io : IO, active_tab : String = "all")
  title = STATE.config_title
  css = CSS_TEMPLATE
  updated_at = STATE.updated_at.to_s
  tabs = STATE.tabs
  is_development = IS_DEVELOPMENT

  Slang.embed("src/layout.slang", "io")
end

def handle_feed_more(context : HTTP::Server::Context)
  url = context.request.query_params["url"]?
  limit = context.request.query_params["limit"]?.try(&.to_i?) || 20

  if url && (config = STATE.config)
    # Search top-level feeds and all feeds within tabs
    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)

    if feed_config = all_feeds.find { |f| f.url == url }
      # Force fetch with new limit (pass nil for previous_data to avoid 304 and force re-parse)
      data = fetch_feed(feed_config, limit, nil)
      context.response.content_type = "text/html; charset=utf-8"
      feeds = [data]
      releases = [] of FeedData
      Slang.embed("src/feed_boxes.slang", "context.response")
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
        if redirects > 3
          context.response.status_code = 502
          break
        end

        loop_uri = URI.parse(current_url)
        loop_client = POOL.for(current_url)
        loop_headers = HTTP::Headers{"User-Agent" => "Mozilla/5.0 (compatible; QuickHeadlines/1.0)"}

        begin
          loop_client.get(loop_uri.request_target, headers: loop_headers) do |response|
            if response.status.redirection? && (location = response.headers["Location"]?)
              current_url = loop_uri.resolve(location).to_s
              redirects += 1
            elsif response.status.success?
              context.response.content_type = response.content_type || "image/png"
              context.response.headers["Cache-Control"] = "public, max-age=86400"
              IO.copy(response.body_io, context.response)
              success = true
            else
              context.response.status_code = response.status_code
              success = true
            end
          end
        ensure
          loop_client.close
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

def start_server(port : Int32)
  server = HTTP::Server.new do |context|
    # Determine active tab from query param, defaulting to the first tab
    active_tab = context.request.query_params["tab"]? || STATE.tabs.first?.try(&.name) || "all"

    case {context.request.method, context.request.path}
    when {"GET", "/version"}
      context.response.content_type = "text/plain; charset=utf-8"
      # Use updated_at as a change token
      context.response.print STATE.updated_at.to_unix_ms
    when {"GET", "/feeds"}
      context.response.content_type = "text/html; charset=utf-8"
      render_feed_boxes(context.response, active_tab)
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
    else
      context.response.content_type = "text/html; charset=utf-8"
      render_page(context.response, active_tab)
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
