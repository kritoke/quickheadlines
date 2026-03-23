require "athena"
require "../dtos/config_dto"
require "../web/assets"
require "../services/feed_service"
require "../services/story_service"
require "../services/clustering_service"
require "../repositories/feed_repository"
require "../repositories/story_repository"
require "../repositories/cluster_repository"
require "../fetcher/refresh_loop"
require "../websocket"
require "../rate_limiter"

class Quickheadlines::Controllers::ApiController < Athena::Framework::Controller
  @db_service : DatabaseService
  @story_service : Quickheadlines::Services::StoryService?
  @feed_service : Quickheadlines::Services::FeedService?
  @clustering_service : Quickheadlines::Services::ClusteringService?

  # Allowed domains for image proxy (SSRF protection)
  ALLOWED_DOMAINS = {
    "i.imgur.com",
    "pbs.twimg.com",
    "avatars.githubusercontent.com",
    "lh3.googleusercontent.com",
    "i.pravatar.cc",
    "images.unsplash.com",
    "fastly.picsum.photos",
  }

  def self.new : self
    new(DatabaseService.instance)
  end

  def initialize(@db_service : DatabaseService)
  end

  # Validate URL for proxy to prevent SSRF attacks
  private def validate_proxy_url(url : String) : Bool
    begin
      uri = URI.parse(url)
      return false unless uri.scheme.in?("http", "https")
      return false unless uri.host

      host = uri.host.as(String).downcase

      # Check for private network ranges
      return false if host == "localhost"
      return false if host.starts_with?("127.")
      return false if host.starts_with?("192.168.")
      return false if host.starts_with?("10.")
      return false if host.starts_with?("172.16.") || host.starts_with?("172.17.") || host.starts_with?("172.18.") || host.starts_with?("172.19.") || host.starts_with?("172.2") || host.starts_with?("172.30.") || host.starts_with?("172.31.")
      return false if host.starts_with?("169.254.")

      ALLOWED_DOMAINS.includes?(host)
    rescue
      false
    end
  end

  # Generic integer validation with bounds
  private def validate_int(value : String?, default : Int32, min : Int32? = nil, max : Int32? = nil) : Int32
    return default if value.nil?

    begin
      num = value.to_i
      num = min if min && num < min
      num = max if max && num > max
      num
    rescue
      default
    end
  end

  # Validate query parameters with sensible defaults and bounds
  private def validate_limit(value : String?, default : Int32, min : Int32 = 1, max : Int32 = 1000) : Int32
    validate_int(value, default, min, max)
  end

  private def validate_offset(value : String?, default : Int32 = 0) : Int32
    validate_int(value, default, min: 0)
  end

  private def validate_days(value : String?, default : Int32, min : Int32 = 1, max : Int32 = 365) : Int32
    validate_int(value, default, min, max)
  end

  private def story_service : Quickheadlines::Services::StoryService
    @story_service ||= Quickheadlines::Services::StoryService
  end

  private def feed_service : Quickheadlines::Services::FeedService
    @feed_service ||= Quickheadlines::Services::FeedService
  end

  private def clustering_service : Quickheadlines::Services::ClusteringService
    @clustering_service ||= Quickheadlines::Services::ClusteringService.new(
      @db_service.db,
      Quickheadlines::Repositories::ClusterRepository.new(@db_service.db)
    )
  end

  # GET /api/clusters - Get all clustered stories
  @[ARTA::Get(path: "/api/clusters")]
  def clusters(request : ATH::Request) : Quickheadlines::DTOs::ClustersResponse
    clusters = clustering_service.get_all_clusters_from_db

    cluster_responses = clusters.map { |cluster| Quickheadlines::DTOs::ClusterResponse.from_entity(cluster) }

    Quickheadlines::DTOs::ClustersResponse.new(
      clusters: cluster_responses,
      total_count: cluster_responses.size
    )
  end

  # GET /api/clusters/:id/items - Get all items in a cluster
  @[ARTA::Get(path: "/api/clusters/{id}/items")]
  def cluster_items(request : ATH::Request, id : String) : ClusterItemsResponse
    cluster_id = id.to_i64?

    if cluster_id.nil?
      return ClusterItemsResponse.new(
        cluster_id: id,
        items: [] of StoryResponse
      )
    end

    cache = FeedCache.instance
    db_items = cache.get_cluster_items_full(cluster_id)

    items = db_items.map do |item|
      StoryResponse.new(
        id: item[:id].to_s,
        title: item[:title],
        link: item[:link],
        pub_date: item[:pub_date].try(&.to_unix_ms),
        feed_title: item[:feed_title],
        feed_url: item[:feed_url],
        feed_link: "",
        favicon: item[:favicon],
        favicon_data: item[:favicon],
        header_color: item[:header_color]
      )
    end

    ClusterItemsResponse.new(
      cluster_id: id,
      items: items
    )
  end

  # GET /api/feeds - Get feeds for a specific tab
  @[ARTA::Get(path: "/api/feeds")]
  def feeds(request : ATH::Request) : FeedsPageResponse
    # Get tab from query params, default to "all" if empty or not present
    raw_tab = request.query_params["tab"]?
    active_tab = raw_tab.presence || "all"

    cache = FeedCache.instance
    item_limit = StateStore.get.config.try(&.item_limit) || 20

    # Get consistent snapshot of state
    state = StateStore.get
    feeds_snapshot = state.feeds
    tabs_snapshot = state.tabs
    software_releases_snapshot = state.software_releases
    is_clustering = state.clustering

    # Fallback: if STATE is empty (initial load), read directly from cache
    # This ensures feeds work even if STATE wasn't populated yet
    total_feeds = feeds_snapshot.size + tabs_snapshot.sum(&.feeds.size)
    if total_feeds == 0
      feeds_snapshot, tabs_snapshot_hash = load_feeds_from_cache_fallback(cache)
      # Convert tabs hash back to Tab records for consistency
      tabs_snapshot = tabs_snapshot_hash.map { |tab| Tab.new(tab[:name], tab[:feeds], tab[:software_releases]) }
    end

    # Build simple tabs response (just names for tab navigation)
    tabs_response = tabs_snapshot.map do |tab|
      TabResponse.new(name: tab.name)
    end

    # Get feeds for active tab (flattened to top level)
    # For "all" tab, aggregate feeds from all tabs + top-level feeds
    feeds_response = if active_tab.to_s.downcase == "all"
                       # Build list of tuples (feed, tab_name) to preserve tab info
                       all_feeds_with_tabs = [] of {feed: FeedData, tab_name: String}

                       # Top-level feeds have empty tab name (filter out failed feeds)
                       feeds_snapshot.each do |feed|
                         all_feeds_with_tabs << {feed: feed, tab_name: ""} unless feed.failed?
                       end

                       # Tab feeds have their tab name (filter out failed feeds)
                       tabs_snapshot.each do |tab|
                         tab.feeds.each do |feed|
                           all_feeds_with_tabs << {feed: feed, tab_name: tab.name} unless feed.failed?
                         end
                       end

                       all_feeds_with_tabs.map { |entry| Api.feed_to_response(entry[:feed], entry[:tab_name], cache.item_count(entry[:feed].url), item_limit) }
                     else
                       found_tab = tabs_snapshot.find { |tab| tab.name.to_s.downcase == active_tab.downcase }
                       active_feeds = found_tab ? found_tab.feeds.reject(&.failed?) : [] of FeedData
                       active_feeds.map { |feed| Api.feed_to_response(feed, active_tab, cache.item_count(feed.url), item_limit) }
                     end

    # Get software releases - from all tabs when active_tab=all, otherwise from specific tab
    releases_response = if active_tab.to_s.downcase == "all"
                          # Aggregate software releases from all tabs
                          all_software = software_releases_snapshot.dup
                          tabs_snapshot.each do |tab|
                            all_software.concat(tab.software_releases)
                          end
                          all_software.map { |release| Api.feed_to_response(release, "software", release.items.size, item_limit) }
                        else
                          found_tab = tabs_snapshot.find { |tab| tab.name.to_s.downcase == active_tab.downcase }
                          tab_software = found_tab ? found_tab.software_releases : [] of FeedData
                          if tab_software
                            tab_software.map { |release| Api.feed_to_response(release, "software", release.items.size, item_limit) }
                          else
                            [] of FeedResponse
                          end
                        end

    FeedsPageResponse.new(
      tabs: tabs_response,
      active_tab: active_tab,
      feeds: feeds_response,
      software_releases: releases_response,
      clustering: is_clustering,
      updated_at: STATE.updated_at.to_unix_ms
    )
  end

  # GET /api/feed_more - Get more items for a specific feed
  @[ARTA::Get(path: "/api/feed_more")]
  def feed_more(request : ATH::Request) : FeedResponse
    url = request.query_params["url"]?
    limit = validate_limit(request.query_params["limit"]?, 10)
    offset = validate_offset(request.query_params["offset"]?)

    if url.nil? || url.strip.empty?
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
        db_fetch_limit = STATE.config.try(&.db_fetch_limit) || 500
        fetch_feed(feed_config, needed_count + 50, db_fetch_limit, nil)
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
    default_limit = STATE.config.try(&.db_fetch_limit) || 500
    default_days = (STATE.config.try(&.cache_retention_hours) || 168) / 24
    limit = validate_limit(request.query_params["limit"]?, default_limit, max: 1000)
    offset = validate_offset(request.query_params["offset"]?)
    days = validate_days(request.query_params["days"]?, default_days.to_i32)
    tab = request.query_params["tab"]?

    # Get allowed feed URLs for the tab (if specific tab selected)
    allowed_feed_urls = [] of String
    if tab && tab.downcase != "all"
      state = StateStore.get
      tabs_snapshot = state.tabs
      found_tab = tabs_snapshot.find { |t| t.name.downcase == tab.downcase }
      
      # FALLBACK: if StateStore is empty or tab has no feeds, load from cache
      if found_tab.nil? || found_tab.feeds.empty?
        cache = FeedCache.instance
        _, tabs_hash = load_feeds_from_cache_fallback(cache)
        found_tab_hash = tabs_hash.find { |t| t[:name].downcase == tab.downcase }
        if found_tab_hash
          allowed_feed_urls = found_tab_hash[:feeds].map(&.url)
        end
      elsif found_tab
        allowed_feed_urls = found_tab.feeds.map(&.url)
      end
    end

    story_repo = Quickheadlines::Repositories::StoryRepository.new(@db_service.db)
    result = Quickheadlines::Services::StoryService.get_timeline(story_repo, limit, offset, days, allowed_feed_urls)

    # If timeline has very few items and we're not already clustering, trigger a background refresh
    # This ensures the timeline populates quickly after server startup
    if result.total_count < 100 && !STATE.clustering? && offset == 0
      spawn do
        begin
          config = STATE.config
          if config
            refresh_all(config)
          end
        rescue ex
          STDERR.puts "[Timeline] Background refresh error: #{ex.message}"
        end
      end
    end

    TimelinePageResponse.new(
      items: result.items,
      has_more: result.has_more?,
      total_count: result.total_count,
      clustering: STATE.clustering?
    )
  end

  # GET /api/version - Get version for update checking
  @[ARTA::Get(path: "/api/version")]
  def version : ATH::View(VersionResponse)
    view(VersionResponse.new(
      updated_at: STATE.updated_at.to_unix_ms,
      clustering: STATE.clustering?
    ))
  end

  # GET /api/config - Get configuration settings
  @[ARTA::Get(path: "/api/config")]
  def config : ATH::View(Quickheadlines::DTOs::ConfigResponse)
    config = STATE.config
    refresh_minutes = config.try(&.refresh_minutes) || 10
    item_limit = config.try(&.item_limit) || 20
    debug = config.try(&.debug?) || false

    view(Quickheadlines::DTOs::ConfigResponse.new(
      refresh_minutes: refresh_minutes,
      item_limit: item_limit,
      debug: debug
    ))
  end

  # GET /api/tabs - Lightweight endpoint to get just tab names (no feed data)
  @[ARTA::Get(path: "/api/tabs")]
  def tabs : ATH::View(TabsResponse)
    state = StateStore.get
    tabs_snapshot = state.tabs

    # Fallback: if STATE is empty, read from config
    if tabs_snapshot.empty?
      config = STATE.config
      if config
        tabs_snapshot = config.tabs
      end
    end

    tabs_response = tabs_snapshot.map do |tab|
      TabResponse.new(name: tab.name)
    end

    view(TabsResponse.new(tabs: tabs_response))
  end

  # GET /version - Get version as plain text (legacy endpoint)
  @[ARTA::Get(path: "/version")]
  def version_text : String
    STATE.updated_at.to_unix_ms.to_s
  end

  private def parse_header_color_params(body : JSON::Any) : Tuple(String?, String?, String?)
    feed_url = (val = body["feed_url"]?) && val.is_a?(JSON::Any) ? val.as_s : nil
    color = (val = body["color"]?) && val.is_a?(JSON::Any) ? val.as_s : nil
    text_color = (val = body["text_color"]?) && val.is_a?(JSON::Any) ? val.as_s : nil
    {feed_url, color, text_color}
  end

  private def normalize_feed_url(url : String) : String
    url.strip
      .rstrip('/')
      .gsub(/\/rss(\.xml)?$/i, "")
      .gsub(/\/feed(\.xml)?$/i, "")
  end

  private def has_manual_color_override?(config : Config, feed_url : String) : Bool
    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)
    all_feeds.any? { |feed| feed.url == feed_url && !feed.header_color.to_s.empty? }
  end

  # POST /api/header_color - Save extracted header color and text color from favicon
  # Takes feed_url, color (bg color), and text_color (text color). Manual header_color in config takes priority.
  @[ARTA::Post(path: "/api/header_color")]
  def save_header_color(request : ATH::Request) : ATH::Response
    body_io = request.body
    return ATH::Response.new("Missing request body", 400) if body_io.nil?

    body = JSON.parse(body_io.gets_to_end)
    feed_url, color, text_color = parse_header_color_params(body)

    if feed_url.nil? || color.nil? || text_color.nil?
      return ATH::Response.new("Missing feed_url, color, or text_color", 400)
    end

    config = STATE.config
    return ATH::Response.new("Configuration not loaded", 500) if config.nil?

    if has_manual_color_override?(config, feed_url)
      return ATH::Response.new("Skipped: manual config exists", 200)
    end

    normalized_url = normalize_feed_url(feed_url)
    cache = FeedCache.instance
    db_url = cache.find_feed_url_by_pattern(normalized_url) || feed_url

    cache.update_header_colors(db_url, color, text_color)
    ATH::Response.new("OK", 200)
  rescue ex
    ATH::Response.new(ex.message, 500)
  end

  @[ARTA::Get(path: "/favicon.png")]
  def favicon_png(request : ATH::Request) : ATH::Response
    content = FrontendAssets.get("favicon.png").gets_to_end
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/png"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/sun-icon.svg")]
  def sun_icon_svg(request : ATH::Request) : ATH::Response
    content = FrontendAssets.get("sun-icon.svg").gets_to_end
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/moon-icon.svg")]
  def moon_icon_svg(request : ATH::Request) : ATH::Response
    content = FrontendAssets.get("moon-icon.svg").gets_to_end
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/home-icon.svg")]
  def home_icon_svg(request : ATH::Request) : ATH::Response
    content = FrontendAssets.get("home-icon.svg").gets_to_end
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  @[ARTA::Get(path: "/timeline-icon.svg")]
  def timeline_icon_svg(request : ATH::Request) : ATH::Response
    content = FrontendAssets.get("timeline-icon.svg").gets_to_end
    response = ATH::Response.new(content)
    response.headers["content-type"] = "image/svg+xml"
    response.headers["Cache-Control"] = "public, max-age=31536000"
    response.headers["Access-Control-Allow-Origin"] = "*"
    response
  end

  # Proxy images
  @[ARTA::Get(path: "/proxy_image")]
  def proxy_image(request : ATH::Request) : ATH::Response
    if url = request.query_params["url"]?
      unless validate_proxy_url(url)
        return ATH::Response.new("Domain not allowed", 400, HTTP::Headers{"content-type" => "text/plain"})
      end

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

          # Validate redirect URL
          unless validate_proxy_url(current_url)
            return ATH::Response.new("Domain not allowed", 400, HTTP::Headers{"content-type" => "text/plain"})
          end

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

  # POST /api/cluster - Unified clustering endpoint
  # Actions: run (cluster uncategorized), recluster (clear and re-cluster)
  @[ARTA::Post(path: "/api/cluster")]
  def cluster(request : ATH::Request) : ATH::Response
    limiter = RateLimiter.get_or_create("cluster", 1, 60)
    # Use simple key since Athena doesn't provide remote_ip directly
    client_key = "cluster_endpoint"

    unless limiter.allowed?(client_key)
      retry_after = limiter.retry_after(client_key)
      return ATH::Response.new(
        "Rate limit exceeded. Try again later.",
        429,
        HTTP::Headers{
          "content-type" => "text/plain",
          "Retry-After"  => retry_after.to_s,
        }
      )
    end

    spawn do
      begin
        service = clustering_service
        cluster_limit = STATE.config.try(&.clustering).try(&.max_items) || STATE.config.try(&.db_fetch_limit) || 5000
        threshold = STATE.config.try(&.clustering).try(&.threshold) || 0.35

        if STATE.config.try(&.debug?)
          STDERR.puts "[#{Time.local}] Running clustering..."
        end
        service.recluster_with_lsh(cluster_limit, threshold)
      rescue ex
        STDERR.puts "[#{Time.local}] Clustering error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n")
      end
    end

    ATH::Response.new("Clustering started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  # POST /api/admin - Unified admin actions: clear-cache, cleanup-orphaned
  @[ARTA::Post(path: "/api/admin")]
  def admin(request : ATH::Request) : ATH::Response
    limiter = RateLimiter.get_or_create("admin", 1, 60)
    # Use simple key since Athena doesn't provide remote_ip directly
    client_key = "admin_endpoint"

    unless limiter.allowed?(client_key)
      retry_after = limiter.retry_after(client_key)
      return ATH::Response.new(
        "Rate limit exceeded. Try again later.",
        429,
        HTTP::Headers{
          "content-type" => "text/plain",
          "Retry-After"  => retry_after.to_s,
        }
      )
    end

    action = "cleanup-orphaned"

    spawn do
      begin
        cache = FeedCache.instance
        db = cache.db

        case action
        when "clear-cache"
          feed_count = db.query_one("SELECT COUNT(*) FROM feeds", as: Int64)
          item_count = db.query_one("SELECT COUNT(*) FROM items", as: Int64)

          db.exec("DELETE FROM items")
          db.exec("DELETE FROM feeds")
          cache.clear_clustering_metadata
          cache.clear_all

          STDERR.puts "[#{Time.local}] Cache cleared: #{feed_count} feeds, #{item_count} items deleted"
        when "cleanup-orphaned"
          config_urls = Set(String).new
          STATE.feeds.each { |feed| config_urls << feed.url }
          STATE.tabs.each do |tab|
            tab.feeds.each { |feed| config_urls << feed.url }
          end

          cluster_repo = Quickheadlines::Repositories::ClusterRepository.new(db)
          feed_repo = Quickheadlines::Repositories::FeedRepository.new(db)
          existing_feeds = feed_repo.find_all
          db_urls = existing_feeds.map(&.url).to_set

          orphaned = db_urls - config_urls

          if orphaned.empty?
            STDERR.puts "[#{Time.local}] No orphaned feeds to clean up"
          else
            deleted_items = 0
            orphaned.each do |url|
              item_count = feed_repo.count_items(url)
              deleted_items += item_count
              feed_repo.delete_by_url(url)
            end

            cluster_repo.clear_all_metadata
            STDERR.puts "[#{Time.local}] Cleaned up #{orphaned.size} orphaned feeds (#{deleted_items} items deleted)"
          end
        end
      rescue ex
        STDERR.puts "[#{Time.local}] Admin action error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n") if ex.backtrace
      end
    end

    ATH::Response.new("Admin action started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  # GET /api/status - Get current system status
  @[ARTA::Get(path: "/api/status")]
  def status : Quickheadlines::DTOs::StatusResponse
    ws_stats = SocketManager.instance.stats
    broadcaster_stats = EventBroadcaster.stats

    Quickheadlines::DTOs::StatusResponse.new(
      clustering: STATE.clustering?,
      refreshing: STATE.refreshing?,
      active_jobs: 0,
      websocket_connections: ws_stats["connections"].to_i32,
      websocket_messages_sent: ws_stats["messages_sent"].to_i64,
      websocket_messages_dropped: ws_stats["messages_dropped"].to_i64,
      websocket_send_errors: ws_stats["send_errors"].to_i64,
      broadcaster_processed: broadcaster_stats["processed"].to_i64,
      broadcaster_dropped: broadcaster_stats["dropped"].to_i64
    )
  end

  # GET /.well-known/appspecific/com.chrome.devtools.json - Chrome DevTools config
  # This endpoint is requested by Chrome DevTools but we don't use it, so return 404
  @[ARTA::Get(path: "/.well-known/appspecific/com.chrome.devtools.json")]
  def chrome_devtools_config : ATH::Response
    ATH::Response.new(
      "Not Found",
      status: :not_found,
      headers: HTTP::Headers{"Content-Type" => "text/plain"}
    )
  end

  # Fallback method to load feeds directly from cache when STATE is empty
  private def load_feeds_from_cache_fallback(cache : FeedCache)
    config = STATE.config
    return {[] of FeedData, [] of NamedTuple(name: String, feeds: Array(FeedData), software_releases: Array(FeedData))} unless config

    cached_feeds = [] of FeedData
    config.feeds.each do |feed_config|
      if cached = cache.get(feed_config.url)
        cached_feeds << cached
      end
    end

    cached_tabs = config.tabs.map do |tab_config|
      tab_feeds = tab_config.feeds.compact_map do |feed_config|
        cached = cache.get(feed_config.url)
        cached || cache.get(normalize_url(feed_config.url))
      end
      {name: tab_config.name, feeds: tab_feeds, software_releases: [] of FeedData}
    end

    {cached_feeds, cached_tabs}
  end

  private def normalize_url(url : String) : String
    url.sub("https://www.", "https://").sub("http://www.", "http://")
  end
end
