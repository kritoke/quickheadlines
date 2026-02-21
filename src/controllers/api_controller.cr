require "athena"
require "../rate_limiter"
require "../dtos/rate_limit_stats_dto"
require "../dtos/config_dto"
require "../web/assets"

class Quickheadlines::Controllers::ApiController < Athena::Framework::Controller
  @db_service : DatabaseService

  def self.new : self
    new(DatabaseService.instance)
  end

  def initialize(@db_service : DatabaseService)
  end

  private def check_rate_limit(request : ATH::Request) : Bool
    return true if request.path.starts_with?("/api/admin")

    ip = request.request.remote_address.try(&.to_s) || "unknown"
    category = Quickheadlines::RateLimiting::RateLimitConfig.get_category(request.path)

    result = rate_limiter.check_limit(ip, category)

    unless result[:allowed]
      STDERR.puts "[#{Time.local}] Rate limit exceeded for #{ip} on #{request.path}"
      return false
    end

    true
  end

  # GET /api/clusters - Get all clustered stories
  @[ARTA::Get(path: "/api/clusters")]
  def clusters(request : ATH::Request) : Quickheadlines::DTOs::ClustersResponse
    unless check_rate_limit(request)
      return Quickheadlines::DTOs::ClustersResponse.new(
        clusters: [] of Quickheadlines::DTOs::ClusterResponse,
        total_count: 0
      )
    end

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

  # GET /api/clusters/:id/items - Get all items in a cluster
  @[ARTA::Get(path: "/api/clusters/{id}/items")]
  def cluster_items(request : ATH::Request, id : String) : ClusterItemsResponse
    unless check_rate_limit(request)
      return ClusterItemsResponse.new(
        cluster_id: id,
        items: [] of StoryResponse
      )
    end

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
    item_limit = STATE.config.try(&.item_limit) || 20

    # Get consistent snapshot of state under lock
    feeds_snapshot, tabs_snapshot, software_releases_snapshot, is_clustering = STATE.with_lock do
      {
        STATE.feeds.dup,
        STATE.tabs.map { |tab| {name: tab.name, feeds: tab.feeds.dup, software_releases: tab.software_releases.dup} },
        STATE.software_releases.dup,
        STATE.is_clustering?,
      }
    end

    # Fallback: if STATE is empty (initial load), read directly from cache
    if feeds_snapshot.empty? && tabs_snapshot.all?(&.[:feeds].empty?)
      feeds_snapshot, tabs_snapshot = load_feeds_from_cache_fallback(cache)
    end

    # Build simple tabs response (just names for tab navigation)
    tabs_response = tabs_snapshot.map do |tab|
      TabResponse.new(name: tab[:name])
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
                         tab[:feeds].each do |feed|
                           all_feeds_with_tabs << {feed: feed, tab_name: tab[:name]} unless feed.failed?
                         end
                       end

                       all_feeds_with_tabs.map { |entry| Api.feed_to_response(entry[:feed], entry[:tab_name], cache.item_count(entry[:feed].url), item_limit) }
                     else
                       found_tab = tabs_snapshot.find { |tab| tab[:name].downcase == active_tab.downcase }
                       active_feeds = found_tab ? found_tab[:feeds].reject(&.failed?) : [] of FeedData
                       active_feeds.map { |feed| Api.feed_to_response(feed, active_tab, cache.item_count(feed.url), item_limit) }
                     end

    # Get software releases - from all tabs when active_tab=all, otherwise from specific tab
    releases_response = if active_tab.to_s.downcase == "all"
                          # Aggregate software releases from all tabs
                          all_software = software_releases_snapshot.dup
                          tabs_snapshot.each do |tab|
                            all_software.concat(tab[:software_releases])
                          end
                          all_software.map { |release| Api.feed_to_response(release, "software", release.items.size, item_limit) }
                        else
                          found_tab = tabs_snapshot.find { |tab| tab[:name].downcase == active_tab.downcase }
                          tab_software = found_tab ? found_tab[:software_releases] : nil
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
      is_clustering: is_clustering,
      updated_at: STATE.updated_at.to_unix_ms
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
    default_limit = STATE.config.try(&.db_fetch_limit) || 500
    default_days = (STATE.config.try(&.cache_retention_hours) || 168) / 24
    limit = request.query_params["limit"]?.try(&.to_i?) || default_limit
    offset = request.query_params["offset"]?.try(&.to_i?) || 0
    days = request.query_params["days"]?.try(&.to_i?) || default_days.to_i32

    # Query database directly for items - use days from config if not specified
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
        header_text_color: item[:header_text_color],
        cluster_id: item[:cluster_id].try(&.to_s),
        is_representative: item[:is_representative],
        cluster_size: item[:cluster_size]
      )
    end

    TimelinePageResponse.new(
      items: items_response,
      has_more: has_more,
      total_count: total_count,
      is_clustering: STATE.is_clustering?
    )
  end

  # GET /api/version - Get version for update checking
  @[ARTA::Get(path: "/api/version")]
  def version : ATH::View(VersionResponse)
    self.view(VersionResponse.new(
      updated_at: STATE.updated_at.to_unix_ms,
      is_clustering: STATE.is_clustering?
    ))
  end

  # GET /api/config - Get configuration settings
  @[ARTA::Get(path: "/api/config")]
  def config : ATH::View(Quickheadlines::DTOs::ConfigResponse)
    config = STATE.config
    refresh_minutes = config.try(&.refresh_minutes) || 10
    item_limit = config.try(&.item_limit) || 20

    self.view(Quickheadlines::DTOs::ConfigResponse.new(
      refresh_minutes: refresh_minutes,
      item_limit: item_limit
    ))
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

    # Normalize URL to match database format (remove trailing slashes, /feed, etc.)
    normalized_url = feed_url.strip
      .rstrip('/')
      .gsub(/\/rss(\.xml)?$/i, "")
      .gsub(/\/feed(\.xml)?$/i, "")

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
      return ATH::Response.new("Skipped: manual config exists", 200)
    end

    # Try to find matching feed in database with normalized URL
    cache = FeedCache.instance
    db_url = cache.find_feed_url_by_pattern(normalized_url)

    if db_url.nil?
      # Fallback: try original URL
      db_url = feed_url
    end

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

  # GET /api/admin/rate-limit-stats - Get rate limiting statistics
  @[ARTA::Get(path: "/api/admin/rate-limit-stats")]
  def rate_limit_stats : Quickheadlines::DTOs::RateLimitStatsResponse
    stats = rate_limiter.stats
    Quickheadlines::DTOs::RateLimitStatsResponse.new(
      total_entries: stats[:total_entries],
      by_category: stats[:by_category]
    )
  end

  # POST /api/run-clustering - Manually trigger clustering on all uncategorized items
  @[ARTA::Post(path: "/api/run-clustering")]
  def run_clustering : ATH::Response
    spawn do
      begin
        STDERR.puts "[#{Time.local}] Starting manual clustering..."
        service = clustering_service
        cluster_limit = STATE.config.try(&.clustering).try(&.max_items) || STATE.config.try(&.db_fetch_limit) || 5000
        threshold = STATE.config.try(&.clustering).try(&.threshold) || 0.35
        service.cluster_uncategorized(cluster_limit, threshold)
      rescue ex
        STDERR.puts "[#{Time.local}] Clustering error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n")
      end
    end

    ATH::Response.new("Clustering started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  # POST /api/recluster - Clear cluster metadata and re-cluster all items
  @[ARTA::Post(path: "/api/recluster")]
  def recluster : ATH::Response
    spawn do
      begin
        STDERR.puts "[#{Time.local}] Clearing clustering metadata and re-clustering..."
        service = clustering_service
        cluster_limit = STATE.config.try(&.clustering).try(&.max_items) || STATE.config.try(&.db_fetch_limit) || 5000
        threshold = STATE.config.try(&.clustering).try(&.threshold) || 0.35
        service.recluster_all(cluster_limit, threshold)
      rescue ex
        STDERR.puts "[#{Time.local}] Re-clustering error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n")
      end
    end

    ATH::Response.new("Re-clustering started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  # POST /api/cleanup-orphaned - Remove feeds from database that are no longer in config
  @[ARTA::Post(path: "/api/cleanup-orphaned")]
  def cleanup_orphaned_feeds : ATH::Response
    spawn do
      begin
        cache = FeedCache.instance
        db = cache.db

        # Get all feed URLs currently in the database
        db_urls = Set(String).new
        db.query("SELECT DISTINCT url FROM feeds") do |rows|
          rows.each do
            url = rows.read(String)
            db_urls << url
          end
        end

        # Get all feed URLs from current config
        config_urls = Set(String).new
        STATE.feeds.each { |feed| config_urls << feed.url }
        STATE.tabs.each do |tab|
          tab.feeds.each { |feed| config_urls << feed.url }
        end

        # Find orphaned URLs (in DB but not in config)
        orphaned = db_urls - config_urls

        if orphaned.empty?
          STDERR.puts "[#{Time.local}] No orphaned feeds to clean up"
          next
        end

        orphaned_count = 0
        deleted_items = 0
        orphaned.each do |url|
          # Delete items from this feed
          result = db.exec("DELETE FROM items WHERE feed_id IN (SELECT id FROM feeds WHERE url = ?)", url)
          deleted_items += result.rows_affected

          # Delete the feed
          result = db.exec("DELETE FROM feeds WHERE url = ?", url)
          orphaned_count += 1
        end

        # Clean up orphaned LSH band entries
        cache.clear_clustering_metadata

        STDERR.puts "[#{Time.local}] Cleaned up #{orphaned_count} orphaned feeds (#{deleted_items} items deleted)"
      rescue ex
        STDERR.puts "[#{Time.local}] Cleanup error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n") if ex.backtrace
      end
    end

    ATH::Response.new("Cleanup started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  # POST /api/clear-cache - Clear all cached data (feeds, items, favicons, colors)
  # This resets the database to initial state, useful when feeds config changes
  @[ARTA::Post(path: "/api/clear-cache")]
  def clear_cache : ATH::Response
    spawn do
      begin
        cache = FeedCache.instance
        db = cache.db

        # Get counts before deletion
        feed_count = db.query_one("SELECT COUNT(*) FROM feeds", as: Int64)
        item_count = db.query_one("SELECT COUNT(*) FROM items", as: Int64)

        # Delete all items first (foreign key constraint)
        db.exec("DELETE FROM items")

        # Delete all feeds
        db.exec("DELETE FROM feeds")

        # Reset clustering tables
        cache.clear_clustering_metadata

        # Clear in-memory state
        cache.clear_all

        STDERR.puts "[#{Time.local}] Cache cleared: #{feed_count} feeds, #{item_count} items deleted"
      rescue ex
        STDERR.puts "[#{Time.local}] Clear cache error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n") if ex.backtrace
      end
    end

    ATH::Response.new("Cache clear started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  # GET /api/status - Get current system status
  @[ARTA::Get(path: "/api/status")]
  def status : Quickheadlines::DTOs::StatusResponse
    Quickheadlines::DTOs::StatusResponse.new(
      is_clustering: STATE.is_clustering?,
      active_jobs: 0 # We don't track background fiber count yet
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
      tab_feeds = tab_config.feeds.compact_map { |feed_config| cache.get(feed_config.url) }
      {name: tab_config.name, feeds: tab_feeds, software_releases: [] of FeedData}
    end

    {cached_feeds, cached_tabs}
  end
end
