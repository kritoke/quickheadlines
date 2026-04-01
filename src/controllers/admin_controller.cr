require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::AdminController < QuickHeadlines::Controllers::ApiBaseController
  private def with_rate_limit(key_prefix : String, request : ATH::Request) : ATH::Response?
    ip = client_ip(request)
    limiter = RateLimiter.get_or_create("#{key_prefix}:#{ip}", 1, 60)

    unless limiter.allowed?(ip)
      retry_after = limiter.retry_after(ip)
      return ATH::Response.new(
        "Rate limit exceeded. Try again later.",
        429,
        HTTP::Headers{
          "content-type" => "text/plain",
          "Retry-After"  => retry_after.to_s,
        }
      )
    end
    nil
  end

  @[ARTA::Post(path: "/api/cluster")]
  def cluster(request : ATH::Request) : ATH::Response
    unless check_admin_auth(request)
      return unauthorized_response
    end

    if response = with_rate_limit("cluster", request)
      return response
    end

    spawn do
      begin
        service = clustering_service
        cluster_limit = StateStore.config.try(&.clustering).try(&.max_items) || StateStore.config.try(&.db_fetch_limit) || 5000
        threshold = StateStore.config.try(&.clustering).try(&.threshold) || 0.35

        if StateStore.config.try(&.debug?)
          STDERR.puts "[#{Time.local}] Running clustering..."
        end
        service.recluster_with_lsh(@feed_cache, cluster_limit, threshold)
      rescue ex
        STDERR.puts "[#{Time.local}] Clustering error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n")
      end
    end

    ATH::Response.new("Clustering started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  @[ARTA::Post(path: "/api/admin")]
  def admin(request : ATH::Request) : ATH::Response
    unless check_admin_auth(request)
      return unauthorized_response
    end

    if response = with_rate_limit("admin", request)
      return response
    end

    body_io = request.body
    action = nil

    if body_io
      body_content = body_io.gets_to_end
      if !body_content.empty?
        begin
          body_json = JSON.parse(body_content)
          action = body_json["action"]?.try(&.as_s?)
        rescue
        end
      end
    end

    unless action
      return ATH::Response.new(
        "{\"error\": \"Missing action field\"}",
        400,
        HTTP::Headers{"content-type" => "application/json"}
      )
    end

    unless action.in?("clear-cache", "cleanup-orphaned")
      return ATH::Response.new(
        "{\"error\": \"Unknown action\"}",
        400,
        HTTP::Headers{"content-type" => "application/json"}
      )
    end

    spawn do
      begin
        cache = @feed_cache
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
          StateStore.feeds.each { |feed| config_urls << feed.url }
          StateStore.tabs.each do |tab|
            tab.feeds.each { |feed| config_urls << feed.url }
          end

          cluster_repo = QuickHeadlines::Repositories::ClusterRepository.new(@db_service)
          feed_repo = QuickHeadlines::Repositories::FeedRepository.new(@db_service)
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

  @[ARTA::Get(path: "/api/status")]
  def status : QuickHeadlines::DTOs::StatusResponse
    ws_stats = @socket_manager.stats
    broadcaster_stats = EventBroadcaster.stats

    QuickHeadlines::DTOs::StatusResponse.new(
      clustering: StateStore.clustering?,
      refreshing: StateStore.refreshing?,
      active_jobs: 0,
      websocket_connections: ws_stats["connections"].to_i32,
      websocket_messages_sent: broadcaster_stats["sent"].to_i64,
      websocket_messages_dropped: broadcaster_stats["dropped"].to_i64,
      websocket_send_errors: ws_stats["send_errors"].to_i64,
      broadcaster_processed: broadcaster_stats["processed"].to_i64,
      broadcaster_dropped: broadcaster_stats["dropped"].to_i64
    )
  end

  @[ARTA::Get(path: "/api/version")]
  def version : ATH::View(VersionResponse)
    view(VersionResponse.new(
      updated_at: StateStore.updated_at.to_unix_ms,
      clustering: StateStore.clustering?
    ))
  end

  @[ARTA::Get(path: "/version")]
  def version_text : String
    StateStore.updated_at.to_unix_ms.to_s
  end
end
