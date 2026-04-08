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
          Log.for("quickheadlines.clustering").debug { "Running clustering..." }
        end
        service.recluster_with_lsh(@feed_cache, cluster_limit, threshold)
      rescue ex
        Log.for("quickheadlines.clustering").error(exception: ex) { "Clustering error" }
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
      begin
        body_content = read_body_safe(body_io)
        if !body_content.empty?
          body_json = JSON.parse(body_content)
          action = body_json["action"]?.try(&.as_s?)
        end
      rescue IO::EOFError
        return ATH::Response.new("Request body too large", 413, HTTP::Headers{"content-type" => "application/json"})
      rescue JSON::ParseException
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

          begin
            db.exec("BEGIN TRANSACTION")
            db.exec("DELETE FROM items")
            db.exec("DELETE FROM feeds")
            cache.clear_clustering_metadata
            cache.clear_all
            db.exec("COMMIT")
          rescue ex
            db.exec("ROLLBACK")
            raise ex
          end

          Log.for("quickheadlines.app").info { "Cache cleared: #{feed_count} feeds, #{item_count} items deleted" }
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
            Log.for("quickheadlines.app").info { "No orphaned feeds to clean up" }
          else
            placeholders = orphaned.map { |_| "?" }.join(",")
            deleted_items = db.exec("DELETE FROM items WHERE feed_id IN (SELECT id FROM feeds WHERE url IN (#{placeholders}))", args: orphaned.map { |url| url }).rows_affected

            db.exec("DELETE FROM feeds WHERE url IN (#{placeholders})", args: orphaned)

            cluster_repo.clear_all_metadata
            Log.for("quickheadlines.app").info { "Cleaned up #{orphaned.size} orphaned feeds (#{deleted_items} items deleted)" }
          end
        end
      rescue ex
        Log.for("quickheadlines.app").error(exception: ex) { "Admin action error" }
      end
    end

    ATH::Response.new("Admin action started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  @[ARTA::Get(path: "/api/status")]
  def status(request : ATH::Request) : ATH::Response
    unless check_admin_auth(request)
      return unauthorized_response
    end

    ws_stats = @socket_manager.stats
    broadcaster_stats = EventBroadcaster.stats

    body = {
      "clustering"                 => StateStore.clustering?,
      "refreshing"                 => StateStore.refreshing?,
      "active_jobs"                => 0,
      "websocket_connections"      => ws_stats["connections"].to_i32,
      "websocket_messages_sent"    => broadcaster_stats["sent"].to_i64,
      "websocket_messages_dropped" => broadcaster_stats["dropped"].to_i64,
      "websocket_send_errors"      => ws_stats["send_errors"].to_i64,
      "broadcaster_processed"      => broadcaster_stats["processed"].to_i64,
      "broadcaster_dropped"        => broadcaster_stats["dropped"].to_i64,
    }.to_json

    ATH::Response.new(body, 200, HTTP::Headers{"content-type" => "application/json"})
  end

  @[ARTA::Get(path: "/api/version")]
  def version(request : ATH::Request) : ATH::Response
    unless check_admin_auth(request)
      return unauthorized_response
    end

    body = {
      "updated_at" => StateStore.updated_at.to_unix_ms,
      "clustering" => StateStore.clustering?,
    }.to_json

    ATH::Response.new(body, 200, HTTP::Headers{"content-type" => "application/json"})
  end

  @[ARTA::Get(path: "/version")]
  def version_text : String
    StateStore.updated_at.to_unix_ms.to_s
  end
end
