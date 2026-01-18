require "http/server"

# Require local dependencies that are used in this file
require "./config"
require "./fetcher"
require "./models"
require "./storage"
require "./utils"
require "./favicon_storage"
require "./minhash"
require "./elm_js"
require "./api"

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

# Handle embedded elm.js request
def handle_elm_js(context : HTTP::Server::Context)
  ElmJs.serve(context)
end

def handle_version(context : HTTP::Server::Context)
  context.response.content_type = "text/plain; charset=utf-8"
  # Use updated_at as a change token
  context.response.print STATE.updated_at.to_unix_ms
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

# Generate HTML for the main page
def generate_main_page_html : String
  # ameba:disable:next Style/HeredocIndent
  <<-HTML
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{STATE.config_title}</title>
        <link rel="icon" type="image/png" href="/favicon.png">
        <link rel="stylesheet" href="#{CSS_TEMPLATE.starts_with?("/") ? CSS_TEMPLATE : "/css"}">
        <script src="/elm.js"></script>
      </head>
      <body>
        <div id="elm-app"></div>
        <script>
          if (typeof Elm !== 'undefined' && Elm.Main) {
            var app = Elm.Main.init({
              node: document.getElementById('elm-app')
            });
          } else {
            document.getElementById('elm-app').innerHTML = '<p>Loading application...</p>';
          }
        </script>
      </body>
    </html>
  HTML
end

# Route request to appropriate handler
# ameba:disable Metrics/CyclomaticComplexity
def route_request(context : HTTP::Server::Context)
  path = context.request.path

  case {context.request.method, path}
  when {"GET", "/api/feeds"}
    Api.handle_feeds(context)
  when {"GET", "/api/feed_more"}
    Api.handle_feed_more(context)
  when {"GET", "/api/timeline"}
    Api.handle_timeline(context)
  when {"GET", "/api/version"}
    Api.handle_version(context)
  when {"GET", "/version"}
    handle_version(context)
  when {"GET", "/elm.js"}
    handle_elm_js(context)
  when {"GET", "/favicon.png"}
    serve_bytes(context, FAVICON_PNG, "image/png")
  when {"GET", "/favicon.svg"}
    serve_bytes(context, FAVICON_SVG, "image/svg+xml")
  when {"GET", "/favicon.ico"}
    serve_bytes(context, FAVICON_ICO, "image/x-icon")
  when {"GET", "/proxy_image"}
    handle_proxy_image(context)
  when {"GET", "/"}
    context.response.content_type = "text/html; charset=utf-8"
    context.response.print generate_main_page_html
  else
    # Serve main page for all non-API routes (Elm client-side routing)
    if path.starts_with?("/api/") || path.starts_with?("/favicons/") || path == "/elm.js" || path == "/css" || path.starts_with?("/proxy_image")
      if path.starts_with?("/favicons/")
        handle_favicon(context, path)
      else
        context.response.status_code = 404
        context.response.print "404 Not Found"
      end
    else
      # Serve main HTML for client-side routing (handles /timeline, /search, etc.)
      context.response.content_type = "text/html; charset=utf-8"
      context.response.print generate_main_page_html
    end
  end
end

def start_server(port : Int32)
  server = HTTP::Server.new do |context|
    route_request(context)
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
