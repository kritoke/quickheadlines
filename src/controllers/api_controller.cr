require "athena"

class Quickheadlines::Controllers::ApiController < Athena::Framework::Controller
  # GET /api/clusters - Get all clusters
  @[ARTA::Get(path: "/api/clusters")]
  def clusters : Array(Quickheadlines::DTOs::NewsClusterDTO)
    cache = FeedCache.instance

    # Get all clusters by finding unique cluster_ids
    clusters_data = [] of {Int64, Int64, String, Time?, Int32}
    cache.db.query("SELECT id, cluster_id FROM items WHERE cluster_id IS NOT NULL GROUP BY cluster_id ORDER BY cluster_id ASC") do |rows|
      rows.each do
        item_id = rows.read(Int64)
        cluster_id = rows.read(Int64)

        # Get the minimum item_id in the cluster (representative)
        min_id = cache.db.query_one?("SELECT MIN(id) FROM items WHERE cluster_id = ?", cluster_id, as: {Int64})

        if min_id
          # Get item details for representative
          item = cache.db.query_one?("SELECT title, pub_date FROM items WHERE id = ?", min_id, as: {String?, Time?})

          if item
            title, pub_date = item
            cluster_size = cache.get_cluster_size(min_id)

            clusters_data << {min_id, cluster_id, title || "", pub_date, cluster_size}
          end
        end
      end
    end

    # Convert to DTOs
    clusters_data.map do |cluster_entry|
      cluster_id_str = cluster_entry[1].to_s
      title = cluster_entry[2]
      timestamp = cluster_entry[3].try(&.to_s("%YT%H:%-%m-%dM:%S")) || Time.local.to_s("%Y-%m-%dT%H:%M:%S")
      source_count = cluster_entry[4]

      Quickheadlines::DTOs::NewsClusterDTO.new(
        id: cluster_id_str,
        title: title,
        timestamp: timestamp,
        source_count: source_count
      )
    end
  end
  # GET /api/feeds - Get feeds for a specific tab
  @[ARTA::Get(path: "/api/feeds")]
  def feeds(request : ATH::Request) : FeedsPageResponse
    # Get tab from query params, default to "all" if empty or not present
    raw_tab = request.query_params["tab"]?
    active_tab = raw_tab.presence || "all"

    # Build simple tabs response (just names for tab navigation)
    tabs_response = STATE.tabs.map do |tab|
      TabResponse.new(name: tab.name)
    end

    # Get feeds for active tab (flattened to top level as Elm expects)
    # For "all" tab, aggregate feeds from all tabs + top-level feeds
    feeds_response = if active_tab == "all"
                       # Build list of tuples (feed, tab_name) to preserve tab info
                       all_feeds_with_tabs = [] of {feed: FeedData, tab_name: String}

                       # Top-level feeds have empty tab name
                       STATE.feeds.each do |feed|
                         all_feeds_with_tabs << {feed: feed, tab_name: ""}
                       end

                       # Tab feeds have their tab name
                       STATE.tabs.each do |tab|
                         tab.feeds.each do |feed|
                           all_feeds_with_tabs << {feed: feed, tab_name: tab.name}
                         end
                       end

                       all_feeds_with_tabs.map { |entry| Api.feed_to_response(entry[:feed], entry[:tab_name]) }
                     else
                       active_feeds = STATE.feeds_for_tab(active_tab)
                       active_feeds.map { |feed| Api.feed_to_response(feed, active_tab) }
                     end

    FeedsPageResponse.new(
      tabs: tabs_response,
      active_tab: active_tab,
      feeds: feeds_response
    )
  end

  # GET /api/feed_more - Get more items for a specific feed
  @[ARTA::Get(path: "/api/feed_more")]
  def feed_more(request : ATH::Request) : FeedResponse
    url = request.query_params["url"]?
    limit = request.query_params["limit"]?.try(&.to_i?) || 10
    offset = request.query_params["offset"]?.try(&.to_i?) || 0

    if url.nil?
      raise Athena::Framework::Exception::BadRequest.new("Missing 'url' parameter")
    end

    # Search top-level feeds and all feeds within tabs
    config = STATE.config
    if config.nil?
      raise Athena::Framework::Exception::ServiceUnavailable.new("Configuration not loaded")
    end

    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)

    if feed_config = all_feeds.find { |feed| feed.url == url }
      # Find the tab name for this feed
      tab_name = ""
      if tab = config.tabs.find { |tab_item| tab_item.feeds.any? { |feed_item| feed_item.url == url } }
        tab_name = tab.name
      end

      cache = FeedCache.instance

      # Check if we have enough data in the cache
      current_count = 0
      if cached_feed = cache.get(url)
        current_count = cached_feed.items.size
      end

      needed_count = offset + limit

      # Fetch more data if needed
      if current_count < needed_count
        fetch_feed(feed_config, needed_count + 50, nil)
      end

      # Get items from cache
      if data = cache.get(url)
        max_index = Math.min(offset + limit, data.items.size)
        trimmed_items = data.items[0...max_index]

        items_response = trimmed_items.map do |item|
          ItemResponse.new(
            title: item.title,
            link: item.link,
            version: item.version,
            pub_date: item.pub_date.try(&.to_unix_ms)
          )
        end

        FeedResponse.new(
          tab: tab_name,
          url: data.url,
          title: data.title,
          site_link: data.site_link,
          display_link: data.display_link,
          favicon: data.favicon,
          favicon_data: data.favicon_data,
          header_color: data.header_color,
          items: items_response,
          total_item_count: trimmed_items.size.to_i32
        )
      else
        raise Athena::Framework::Exception::ServiceUnavailable.new("Failed to retrieve feed data")
      end
    else
      raise Athena::Framework::Exception::NotFound.new("Feed not found")
    end
  end

  # GET /api/timeline - Get timeline items
  @[ARTA::Get(path: "/api/timeline")]
  def timeline(request : ATH::Request) : TimelinePageResponse
    limit = request.query_params["limit"]?.try(&.to_i?) || 100
    offset = request.query_params["offset"]?.try(&.to_i?) || 0

    # Get all timeline items
    all_items = STATE.all_timeline_items

    total_count = all_items.size
    max_index = Math.min(offset + limit, total_count)
    raw_items = all_items[offset...max_index]

    # Convert to timeline item responses
    items_response = raw_items.map do |item|
      Api.timeline_item_to_response(item)
    end

    has_more = offset + limit < total_count

    TimelinePageResponse.new(
      items: items_response,
      has_more: has_more,
      total_count: total_count.to_i32
    )
  end

  # GET /api/version - Get version for update checking
  @[ARTA::Get(path: "/api/version")]
  def version : VersionResponse
    VersionResponse.new(updated_at: STATE.updated_at.to_unix_ms)
  end

  # GET /version - Get version as plain text (legacy endpoint)
  @[ARTA::Get(path: "/version")]
  def version_text : String
    STATE.updated_at.to_unix_ms.to_s
  end

  # Serve static files
  @[ARTA::Get(path: "/elm.js")]
  def elm_js(request : ATH::Request) : ATH::Response
    content = ElmJs.content
    response = ATH::Response.new(content)
    response.headers["content-type"] = "application/javascript; charset=utf-8"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response
  rescue ex : Exception
    ATH::Response.new(ex.message, 404, HTTP::Headers{"content-type" => "text/plain"})
  end

  @[ARTA::Get(path: "/favicon.png")]
  def favicon_png(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/favicon.png")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/png"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response
  end

  @[ARTA::Get(path: "/favicon.svg")]
  def favicon_svg(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/favicon.svg")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response
  end

  @[ARTA::Get(path: "/favicon.ico")]
  def favicon_ico(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/favicon.ico")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/x-icon"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response
  end

  # Serve main HTML page
  @[ARTA::Get(path: "/")]
  @[ARTA::Get(path: "/timeline")]
  def index(request : ATH::Request) : ATH::Response
    # Generate HTML for the main page
    # ameba:disable Style/HeredocIndent
    html = <<-HTML
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{STATE.config_title}</title>
            <link rel="icon" type="image/png" href="/favicon.png">
            <script src="/elm.js?v=#{STATE.updated_at.to_unix_ms}"></script>
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

    response = ATH::Response.new(html)
    response.headers["content-type"] = "text/html; charset=utf-8"
    response
  end

  # Proxy images
  @[ARTA::Get(path: "/proxy_image")]
  def proxy_image(request : ATH::Request) : ATH::Response
    if url = request.query_params["url"]?
      begin
        current_url = url
        redirects = 0
        success = false
        content = IO::Memory.new
        response = ATH::Response.new

        loop do
          loop_uri = URI.parse(current_url)
          loop_client = create_client(current_url)
          loop_headers = HTTP::Headers{
            "User-Agent"      => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language" => "en-US,en;q=0.9",
            "Connection"      => "keep-alive",
          }

          response.status = 502 if redirects > 10
          break if redirects > 10

          begin
            loop_client.get(loop_uri.request_target, headers: loop_headers) do |client_response|
              if client_response.status.redirection? && (location = client_response.headers["Location"]?)
                current_url = loop_uri.resolve(location).to_s
                redirects += 1
              elsif client_response.status.success?
                response.headers["content-type"] = client_response.content_type || "image/png"
                response.headers["Access-Control-Allow-Origin"] = "*"
                response.headers["Cache-Control"] = "public, max-age=86400"
                IO.copy(client_response.body_io, content)
                response.content = content.to_s
                success = true
              else
                response.status = client_response.status_code
                success = true
              end
            end
          end
          break if success
        end

        response
      rescue
        ATH::Response.new("Not found", 404, HTTP::Headers{"content-type" => "text/plain"})
      end
    else
      ATH::Response.new("Missing url parameter", 400, HTTP::Headers{"content-type" => "text/plain"})
    end
  end

  # Serve favicons from storage - handle both with and without trailing slash
  @[ARTA::Get(path: "/favicons/{hash}.{ext}")]
  @[ARTA::Get(path: "/favicons/{hash}.{ext}/")]
  def favicon_file(request : ATH::Request, hash : String, ext : String) : ATH::Response
    filename = "#{hash}.#{ext}"
    filepath = File.join(FaviconStorage::FAVICON_DIR, filename)

    if File.exists?(filepath)
      # Determine content type based on extension
      content_type = case ext.downcase
                     when "png"         then "image/png"
                     when "jpg", "jpeg" then "image/jpeg"
                     when "ico"         then "image/x-icon"
                     when "svg"         then "image/svg+xml"
                     when "webp"        then "image/webp"
                     else                    "image/png"
                     end

      content = File.read(filepath)
      response = ATH::Response.new(content)
      response.headers["content-type"] = content_type
      response.headers["Cache-Control"] = "public, max-age=31536000"
      response
    else
      ATH::Response.new("Favicon not found", 404, HTTP::Headers{"content-type" => "text/plain"})
    end
  end
end
