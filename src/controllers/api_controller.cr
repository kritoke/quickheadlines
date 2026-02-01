require "athena"

class Quickheadlines::Controllers::ApiController < Athena::Framework::Controller
  @db_service : DatabaseService

  def self.new : self
    new(DatabaseService.instance)
  end

  def initialize(@db_service : DatabaseService)
  end

  # GET /api/clusters - Get all clustered stories
  @[ARTA::Get(path: "/api/clusters")]
  def clusters(request : ATH::Request) : Quickheadlines::DTOs::ClustersResponse
    clusters = get_clusters_from_db(@db_service.db)

    cluster_responses = clusters.map { |cluster| Quickheadlines::DTOs::ClusterResponse.from_entity(cluster) }

    Quickheadlines::DTOs::ClustersResponse.new(
      clusters: cluster_responses,
      total_count: cluster_responses.size
    )
  end

  private def get_clusters_from_db(db : DB::Database) : Array(Quickheadlines::Entities::Cluster)
    clusters = [] of Quickheadlines::Entities::Cluster

    # Query to get clusters and their items
    query = <<-SQL
      SELECT
        c.id as cluster_id,
        c.representative_id,
        i.id as item_id,
        i.title as item_title,
        i.link as item_link,
        i.pub_date as item_pub_date,
        f.url as feed_url,
        f.title as feed_title,
        f.favicon,
        f.header_color
      FROM (
        SELECT cluster_id as id, MIN(id) as representative_id
        FROM items
        WHERE cluster_id IS NOT NULL
        GROUP BY cluster_id
      ) c
      JOIN items i ON i.cluster_id = c.id
      JOIN feeds f ON i.feed_id = f.id
      ORDER BY c.id, i.id ASC
      SQL

    # Group items by cluster
    cluster_items = Hash(Int64, Array({id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?})).new

    db.query(query) do |rows|
      rows.each do
        cluster_id = rows.read(Int64)
        representative_id = rows.read(Int64)
        item_id = rows.read(Int64)
        item_title = rows.read(String)
        item_link = rows.read(String)
        item_pub_date_str = rows.read(String?)
        feed_url = rows.read(String)
        feed_title = rows.read(String)
        favicon = rows.read(String?)
        header_color = rows.read(String?)

        item_pub_date = item_pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }

        cluster_items[cluster_id] ||= [] of {id: Int64, title: String, link: String, pub_date: Time?, feed_url: String, feed_title: String, favicon: String?, header_color: String?}
        cluster_items[cluster_id] << {
          id:           item_id,
          title:        item_title,
          link:         item_link,
          pub_date:     item_pub_date,
          feed_url:     feed_url,
          feed_title:   feed_title,
          favicon:      favicon,
          header_color: header_color,
        }
      end
    end

    # Convert to Cluster entities
    cluster_items.each do |_cluster_id, items|
      next if items.empty?

      rep_data = items.first

      representative = Quickheadlines::Entities::Story.new(
        id: rep_data[:id].to_s,
        title: rep_data[:title],
        link: rep_data[:link],
        pub_date: rep_data[:pub_date],
        feed_title: rep_data[:feed_title],
        feed_url: rep_data[:feed_url],
        feed_link: "",
        favicon: rep_data[:favicon],
        favicon_data: rep_data[:favicon],
        header_color: rep_data[:header_color]
      )

      others = items[1..].map do |item|
        Quickheadlines::Entities::Story.new(
          id: item[:id].to_s,
          title: item[:title],
          link: item[:link],
          pub_date: item[:pub_date],
          feed_title: item[:feed_title],
          feed_url: item[:feed_url],
          feed_link: "",
          favicon: item[:favicon],
          favicon_data: item[:favicon],
          header_color: item[:header_color]
        )
      end

      clusters << Quickheadlines::Entities::Cluster.new(
        id: items.first[:id].to_s,
        representative: representative,
        others: others,
        size: items.size
      )
    end

    clusters
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

    cache = FeedCache.instance

    # Get feeds for active tab (flattened to top level as Elm expects)
    # For "all" tab, aggregate feeds from all tabs + top-level feeds
    feeds_response = if active_tab.to_s.downcase == "all"
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

                        all_feeds_with_tabs.map { |entry| Api.feed_to_response(entry[:feed], entry[:tab_name], cache.item_count(entry[:feed].url), STATE.config.try(&.item_limit) || 20) }
                      else
                        active_feeds = STATE.feeds_for_tab(active_tab)
                        active_feeds.map { |feed| Api.feed_to_response(feed, active_tab, cache.item_count(feed.url), STATE.config.try(&.item_limit) || 20) }
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
        fetch_feed(feed_config, needed_count + 50, STATE.config.try(&.db_fetch_limit) || 500, nil)
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
          total_item_count: cache.item_count(url)
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
    limit = request.query_params["limit"]?.try(&.to_i?) || 35
    offset = request.query_params["offset"]?.try(&.to_i?) || 0
    days = request.query_params["days"]?.try(&.to_i?) || 7

    # Query database directly for items from the last N days
    db_items = @db_service.get_timeline_items(limit, offset, days)

    total_count = @db_service.count_timeline_items(days)
    has_more = offset + limit < total_count

    items_response = db_items.map do |item|
      TimelineItemResponse.new(
        id: item[:id].to_s,
        title: item[:title],
        link: item[:link],
        pub_date: item[:pub_date].try(&.to_unix_ms),
        feed_title: item[:feed_title],
        feed_url: item[:feed_url],
        feed_link: item[:feed_link],
        favicon: item[:favicon],
        header_color: item[:header_color],
        header_text_color: nil,
        cluster_id: item[:cluster_id].try(&.to_s),
        is_representative: item[:is_representative],
        cluster_size: item[:cluster_size]
      )
    end

    TimelinePageResponse.new(
      items: items_response,
      has_more: has_more,
      total_count: total_count
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

  # POST /api/header_color - Save extracted header color and text color from favicon
  # Takes feed_url, color (bg color), and text_color (text color). Manual header_color in config takes priority.
  @[ARTA::Post(path: "/api/header_color")]
  def save_header_color(request : ATH::Request) : ATH::Response
    body = JSON.parse(request.body.not_nil!.gets_to_end)

    feed_url_raw = body["feed_url"]?
    color_raw = body["color"]?
    text_color_raw = body["text_color"]?

    feed_url = feed_url_raw.is_a?(JSON::Any) ? feed_url_raw.as_s : nil
    color = color_raw.is_a?(JSON::Any) ? color_raw.as_s : nil
    text_color = text_color_raw.is_a?(JSON::Any) ? text_color_raw.as_s : nil

    if feed_url.nil? || color.nil? || text_color.nil?
      return ATH::Response.new("Missing feed_url, color, or text_color", 400)
    end

    # Check if this feed has a manual header_color in config (takes priority)
    config = STATE.config
    if config.nil?
      return ATH::Response.new("Configuration not loaded", 500)
    end

    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)
    has_manual_color = all_feeds.any? do |feed|
      feed.url == feed_url && !feed.header_color.nil? && feed.header_color != ""
    end

    if has_manual_color
      # Manual config takes priority, don't override
      return ATH::Response.new("Skipped: manual config exists", 200)
    end

    # Save extracted colors to database
    cache = FeedCache.instance
    cache.update_header_colors(feed_url, color, text_color)

    ATH::Response.new("OK", 200)
  rescue ex
    ATH::Response.new(ex.message, 500)
  end

  # Serve static files
  @[ARTA::Get(path: "/elm.js")]
  def elm_js(request : ATH::Request) : ATH::Response
    public_path = "./public/elm.js"
    unless File.exists?(public_path)
      return ATH::Response.new("elm.js not found - run 'make elm-build' first", 404, HTTP::Headers{"content-type" => "text/plain; charset=utf-8"})
    end

    content = File.read(public_path)
    response = ATH::Response.new(content)
    response.headers["content-type"] = "application/javascript; charset=utf-8"
    if ENV["APP_ENV"]? == "development"
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
    else
      response.headers["Cache-Control"] = "public, max-age=31536000"
    end
    response
  rescue ex : Exception
    ATH::Response.new(ex.message, 404, HTTP::Headers{"content-type" => "text/plain"})
  end

  # Serve timeline.css at /public/timeline.css so the SPA can load view-specific styles
  @[ARTA::Get(path: "/public/timeline.css")]
  def public_timeline_css(request : ATH::Request) : ATH::Response
    public_path = "./public/timeline.css"
    unless File.exists?(public_path)
      return ATH::Response.new("public/timeline.css not found - run 'make elm-land-build' or ensure the file exists", 404, HTTP::Headers{"content-type" => "text/plain; charset=utf-8"})
    end

    content = File.read(public_path)
    response = ATH::Response.new(content)
    response.headers["content-type"] = "text/css; charset=utf-8"
    if ENV["APP_ENV"]? == "development"
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
    else
      response.headers["Cache-Control"] = "public, max-age=31536000"
    end
    response
  rescue ex : Exception
    ATH::Response.new(ex.message, 404, HTTP::Headers{"content-type" => "text/plain"})
  end

  # Serve Elm bundle at /public/elm.js (canonical path)
  @[ARTA::Get(path: "/public/elm.js")]
  def public_elm_js(request : ATH::Request) : ATH::Response
    public_path = "./public/elm.js"
    unless File.exists?(public_path)
      return ATH::Response.new("public/elm.js not found - run 'make elm-build' first", 404, HTTP::Headers{"content-type" => "text/plain; charset=utf-8"})
    end

    content = File.read(public_path)
    response = ATH::Response.new(content)
    response.headers["content-type"] = "application/javascript; charset=utf-8"
    if ENV["APP_ENV"]? == "development"
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
    else
      response.headers["Cache-Control"] = "public, max-age=31536000"
    end
    response
  rescue ex : Exception
    ATH::Response.new(ex.message, 404, HTTP::Headers{"content-type" => "text/plain"})
  end

  # Serve Elm Land UI at root
  @[ARTA::Get(path: "/")]
  @[ARTA::Get(path: "/timeline")]
  @[ARTA::Get(path: "/timeline/")]
  def ui_index(request : ATH::Request) : ATH::Response
    html = File.read("./views/index.html")
    response = ATH::Response.new(html)
    response.headers["content-type"] = "text/html; charset=utf-8"
    response
  rescue ex : Exception
    ATH::Response.new(ex.message, 404, HTTP::Headers{"content-type" => "text/plain"})
  end

  @[ARTA::Get(path: "/simple.js")]
  def simple_js(request : ATH::Request) : ATH::Response
    content = File.read("./public/simple.js")
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
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/favicon.svg")]
  def favicon_svg(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/favicon.svg")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/favicon.ico")]
  def favicon_ico(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/favicon.ico")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/x-icon"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/sun-icon.svg")]
  def sun_icon_svg(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/sun-icon.svg")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/moon-icon.svg")]
  def moon_icon_svg(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/moon-icon.svg")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/home-icon.svg")]
  def home_icon_svg(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/home-icon.svg")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/timeline-icon.svg")]
  def timeline_icon_svg(request : ATH::Request) : ATH::Response
    content = File.read("./assets/images/timeline-icon.svg")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  # Simple test page for debugging Elm command execution
  @[ARTA::Get(path: "/simple-test")]
  @[ARTA::Get(path: "/simple")]
  def simple_test(request : ATH::Request) : ATH::Response
    html = <<-HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <title>Simple Test - Debug Elm Commands</title>
          <style>
            body { font-family: monospace; padding: 20px; background: #1a1a1a; color: #eee; }
            button { padding: 10px 20px; margin: 5px; cursor: pointer; background: #333; color: #fff; border: 1px solid #555; }
            #log { background: #0a0a0a; padding: 10px; margin-top: 20px; max-height: 400px; overflow-y: auto; font-size: 12px; }
            .log-entry { margin: 2px 0; padding: 2px 5px; }
            .log-info { color: #88f; }
            .log-success { color: #8f8; }
            .log-error { color: #f88; }
            #elm-app { background: #252525; padding: 20px; margin: 10px 0; border: 1px solid #444; }
          </style>
        </head>
        <body>
          <h1>Simple Elm Test</h1>
          <p>Testing if Elm commands (Task.perform, Http.get) execute on init.</p>
          <button onclick="location.reload()">Reload Page</button>
          <button onclick="clearLog()">Clear Log</button>

          <div id="elm-app"></div>

          <h2>Console Log</h2>
          <div id="log"></div>

          <script src="/simple.js"></script>
          <script>
            function log(msg, type) {
              var logDiv = document.getElementById('log');
              var entry = document.createElement('div');
              entry.className = 'log-entry ' + (type || 'log-info');
              entry.textContent = '[' + new Date().toISOString().substr(11, 12) + '] ' + msg;
              logDiv.appendChild(entry);
              logDiv.scrollTop = logDiv.scrollHeight;
              console.log('[' + type + ']', msg);
            }

            function clearLog() {
              document.getElementById('log').innerHTML = '';
            }

            log('Page loaded', 'log-info');

            // Intercept fetch to see HTTP requests
            var originalFetch = window.fetch;
            window.fetch = function() {
              log('FETCH called: ' + arguments[0], 'log-success');
              return originalFetch.apply(this, arguments);
            };

            // Intercept XMLHttpRequest
            var originalXHR = window.XMLHttpRequest;
            window.XMLHttpRequest = function() {
              var xhr = new originalXHR();
              var originalOpen = xhr.open.bind(xhr);
              xhr.open = function(method, url) {
                log('XHR open: ' + method + ' ' + url, 'log-success');
                return originalOpen.apply(this, arguments);
              };
              return xhr;
            };

            log('Elm global:', typeof Elm, 'log-info');
            log('Elm.SimpleTest:', Elm && Elm.SimpleTest, 'log-info');

            if (typeof Elm !== 'undefined' && Elm.SimpleTest) {
              log('Initializing Elm.SimpleTest...', 'log-info');
              try {
                var startTime = performance.now();
                var app = Elm.SimpleTest.init({
                  node: document.getElementById('elm-app')
                });
                var initTime = performance.now() - startTime;
                log('Elm initialized in ' + initTime.toFixed(2) + 'ms', 'log-success');
                log('App object:', JSON.stringify({
                  ports: !!app.ports,
                  model: !!app.model,
                  subscriptions: !!app.subscriptions
                }), 'log-info');

                // Monitor for model changes
                if (app.ports && app.ports.outgoing) {
                  log('Subscribing to outgoing port', 'log-info');
                  app.ports.outgoing.subscribe(function(data) {
                    log('Outgoing port message: ' + JSON.stringify(data), 'log-success');
                  });
                }

                // Check after a delay if model changed
                setTimeout(function() {
                  log('Checking for updates after 3 seconds...', 'log-info');
                  var modelDiv = document.getElementById('elm-app');
                  log('elm-app innerHTML length: ' + modelDiv.innerHTML.length, 'log-info');
                  log('elm-app text content: ' + modelDiv.textContent.substring(0, 200), 'log-info');

                  // Try to access the app's internal state
                  if (app._callbacks && app._callbacks.update) {
                    log('Update callbacks present', 'log-success');
                  }
                }, 3000);

              } catch(e) {
                log('Elm initialization error: ' + e.message, 'log-error');
                log('Stack: ' + e.stack, 'log-error');
              }
            } else {
              log('Elm.SimpleTest not found!', 'log-error');
              log('Available in Elm:', Object.keys(Elm || {}), 'log-error');
            }
          </script>
        </body>
      </html>
      HTML

    response = ATH::Response.new(html)
    response.headers["content-type"] = "text/html; charset=utf-8"
    response
  end

  # Serve logo (used in header). Prefer public/logo.svg, fall back to assets/images/logo.svg
  @[ARTA::Get(path: "/logo.svg")]
  def logo_svg(request : ATH::Request) : ATH::Response
    public_path = "./public/logo.svg"
    alt_path = "./assets/images/logo.svg"

    # Prefer the asset version (canonical) if present; otherwise fall back to public.
    if File.exists?(alt_path) && File.exists?(public_path)
      # Choose the larger file (likely the full logo) to avoid serving a small placeholder
      path = File.size(alt_path) >= File.size(public_path) ? alt_path : public_path
    elsif File.exists?(alt_path)
      path = alt_path
    else
      path = public_path
    end

    unless File.exists?(path)
      return ATH::Response.new("logo.svg not found", 404, HTTP::Headers{"content-type" => "text/plain"})
    end

    content = File.read(path)
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  rescue ex : Exception
    ATH::Response.new(ex.message, 404, HTTP::Headers{"content-type" => "text/plain"})
  end

  # Vanilla JS test for XHR/Fetch
  @[ARTA::Get(path: "/vanilla-test")]
  def vanilla_test(request : ATH::Request) : ATH::Response
    content = File.read("./public/vanilla-test.html")
    response = ATH::Response.new(content)
    response.headers["content-type"] = "text/html; charset=utf-8"
    response
  rescue ex : Exception
    ATH::Response.new(ex.message, 404, HTTP::Headers{"content-type" => "text/plain"})
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
      # Allow cross-origin access for ColorThief canvas extraction
      response.headers["Access-Control-Allow-Origin"] = "*"
      response
    else
      ATH::Response.new("Favicon not found", 404, HTTP::Headers{"content-type" => "text/plain"})
    end
  end

  # POST /api/run-clustering - Manually trigger clustering on all uncategorized items
  @[ARTA::Post(path: "/api/run-clustering")]
  def run_clustering : ATH::Response
    spawn do
      begin
        STDERR.puts "[#{Time.local}] Starting manual clustering..."

        cache = FeedCache.instance
        db = cache.db

        uncategorized_items = [] of {id: Int64, title: String, link: String, pub_date: Time?}
        db.query("SELECT id, title, link, pub_date FROM items WHERE cluster_id IS NULL OR cluster_id = id ORDER BY pub_date DESC LIMIT 500") do |rows|
          rows.each do
            id = rows.read(Int64)
            title = rows.read(String)
            link = rows.read(String)
            pub_date_str = rows.read(String?)
            pub_date = pub_date_str.try { |str| Time.parse(str, "%Y-%m-%d %H:%M:%S", Time::Location::UTC) }
            uncategorized_items << {id: id, title: title, link: link, pub_date: pub_date}
          end
        end

        STDERR.puts "[#{Time.local}] Found #{uncategorized_items.size} uncategorized items"

        clustered_count = 0
        uncategorized_items.each do |item|
          if item[:title].empty?
            next
          end
          result = compute_cluster_for_item(item[:id], item[:title])
          clustered_count += 1
          if clustered_count % 50 == 0
            STDERR.puts "[#{Time.local}] Processed #{clustered_count} items..."
          end
        end

        STDERR.puts "[#{Time.local}] Clustering complete: #{clustered_count} items processed"
      rescue ex
        STDERR.puts "[#{Time.local}] Clustering error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n")
      end
    end

    ATH::Response.new("Clustering started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end
end
