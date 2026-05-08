require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::AdminController < QuickHeadlines::Controllers::ApiBaseController
  VALID_ADMIN_ACTIONS = {"clear-cache", "cleanup-orphaned"}

  @[ARTA::Post(path: "/api/cluster")]
  def cluster(request : AHTTP::Request) : QuickHeadlines::DTOs::AdminActionResponse
    raise AHK::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    check_rate_limit!(request, "cluster", 1, 60)

    spawn do
      start_time = Time.utc
      begin
        service = clustering_service
        cluster_limit = StateStore.config.try(&.clustering).try(&.max_items) || StateStore.config.try(&.db_fetch_limit) || 5000
        threshold = StateStore.config.try(&.clustering).try(&.threshold) || 0.35

        if StateStore.config.try(&.debug?)
          Log.for("quickheadlines.clustering").debug { "Running clustering..." }
        end
        service.recluster_with_lsh(@feed_cache, cluster_limit, threshold)
        duration_ms = (Time.utc - start_time).total_milliseconds.to_i64
        StateStore.set_cluster_completed(duration_ms, "success")
      rescue ex
        duration_ms = (Time.utc - start_time).total_milliseconds.to_i64
        StateStore.set_cluster_completed(duration_ms, "failed: #{ex.message}")
        Log.for("quickheadlines.clustering").error(exception: ex) { "Clustering error" }
      end
    end

    QuickHeadlines::DTOs::AdminActionResponse.new(status: "started", message: "Clustering started in background")
  end

  @[ARTA::Post(path: "/api/admin")]
  def admin(request : AHTTP::Request) : QuickHeadlines::DTOs::AdminActionResponse
    raise AHK::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    check_rate_limit!(request, "admin", 1, 60)

    body_io = request.body
    action = parse_admin_action(body_io)

    raise AHK::Exception::BadRequest.new("Missing action field") unless action
    raise AHK::Exception::BadRequest.new("Unknown action: #{action}") unless action.in?(VALID_ADMIN_ACTIONS)

    spawn do
      start_time = Time.utc
      begin
        case action
        when "clear-cache"      then handle_clear_cache
        when "cleanup-orphaned" then handle_cleanup_orphaned
        end
        duration_ms = (Time.utc - start_time).total_milliseconds.to_i64
        StateStore.set_admin_completed(action, duration_ms, "success")
      rescue ex
        duration_ms = (Time.utc - start_time).total_milliseconds.to_i64
        StateStore.set_admin_completed(action, duration_ms, "failed: #{ex.message}")
        Log.for("quickheadlines.app").error(exception: ex) { "Admin action error" }
      end
    end

    QuickHeadlines::DTOs::AdminActionResponse.new(status: "started", message: "Admin action started in background")
  end

  private def handle_clear_cache : Nil
    cache = @feed_cache

    feed_count = cache.db.query_one("SELECT COUNT(*) FROM feeds", as: Int64)
    item_count = cache.db.query_one("SELECT COUNT(*) FROM items", as: Int64)

    cache.clear_all

    Log.for("quickheadlines.app").info { "Cache cleared: #{feed_count} feeds, #{item_count} items deleted" }
  end

  private def handle_cleanup_orphaned : Nil
    cache = @feed_cache
    db = cache.db

    config_urls = Set(String).new
    StateStore.feeds.each { |feed| config_urls << feed.url }
    StateStore.tabs.each do |tab|
      tab.feeds.each { |feed| config_urls << feed.url }
    end

    cluster_repo = QuickHeadlines::Repositories::ClusterRepository.new(@db_service)
    feed_repo = QuickHeadlines::Repositories::FeedRepository.new(@db_service)
    db_urls = feed_repo.find_all_urls

    orphaned = db_urls - config_urls

    if orphaned.empty?
      Log.for("quickheadlines.app").info { "No orphaned feeds to clean up" }
      return
    end

    placeholders = QuickHeadlines::Repositories::RepositoryBase.placeholders(orphaned.size)
    deleted_items = db.exec("DELETE FROM items WHERE feed_id IN (SELECT id FROM feeds WHERE url IN (#{placeholders}))", args: orphaned.map { |url| url }).rows_affected

    db.exec("DELETE FROM feeds WHERE url IN (#{placeholders})", args: orphaned)

    cluster_repo.clear_all_metadata
    Log.for("quickheadlines.app").info { "Cleaned up #{orphaned.size} orphaned feeds (#{deleted_items} items deleted)" }
  end

  private def parse_admin_action(body_io : IO?) : String?
    return unless body_io

    body_content = read_body_safe(body_io)
    return if body_content.empty?

    JSON.parse(body_content)["action"]?.try(&.as_s?)
  rescue IO::EOFError
    Log.for("quickheadlines.app").warn { "Admin action: request body too short" }
    nil
  rescue JSON::ParseException
    Log.for("quickheadlines.app").warn { "Admin action: invalid JSON in request body" }
    nil
  end

  @[ARTA::Get(path: "/api/status")]
  def status(request : AHTTP::Request) : QuickHeadlines::DTOs::AdminStatusResponse
    raise AHK::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    ws_stats = @socket_manager.stats
    broadcaster_stats = EventBroadcaster.stats

    QuickHeadlines::DTOs::AdminStatusResponse.new(
      clustering: StateStore.clustering?,
      refreshing: StateStore.refreshing?,
      active_jobs: 0,
      websocket_connections: ws_stats["connections"].to_i32,
      websocket_messages_sent: broadcaster_stats["sent"].to_i64,
      websocket_messages_dropped: broadcaster_stats["dropped"].to_i64,
      websocket_send_errors: ws_stats["send_errors"].to_i64,
      websocket_connections_closed: ws_stats["closed_total"].to_i64,
      broadcaster_processed: broadcaster_stats["processed"].to_i64,
      last_cluster_run: StateStore.last_cluster_run.try(&.to_unix_ms),
      last_cluster_duration_ms: StateStore.last_cluster_duration_ms,
      last_cluster_status: StateStore.last_cluster_status,
      last_admin_action: StateStore.last_admin_action,
      last_admin_run: StateStore.last_admin_run.try(&.to_unix_ms),
      last_admin_duration_ms: StateStore.last_admin_duration_ms,
      last_admin_status: StateStore.last_admin_status,
    )
  end

  @[ARTA::Get(path: "/api/version")]
  def version(request : AHTTP::Request) : QuickHeadlines::DTOs::AdminVersionResponse
    raise AHK::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    QuickHeadlines::DTOs::AdminVersionResponse.new(
      updated_at: StateStore.updated_at.to_unix_ms,
      clustering: StateStore.clustering?,
    )
  end
end
