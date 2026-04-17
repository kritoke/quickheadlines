require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::AdminController < QuickHeadlines::Controllers::ApiBaseController
  VALID_ADMIN_ACTIONS = {"clear-cache", "cleanup-orphaned"}

  @[ARTA::Post(path: "/api/cluster")]
  def cluster(request : ATH::Request) : ATH::Response
    raise ATH::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    check_rate_limit!(request, "cluster", 1, 60)

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
    raise ATH::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    check_rate_limit!(request, "admin", 1, 60)

    body_io = request.body
    action = parse_admin_action(body_io)

    raise ATH::Exception::BadRequest.new("Missing action field") unless action
    raise ATH::Exception::BadRequest.new("Unknown action: #{action}") unless action.in?(VALID_ADMIN_ACTIONS)

    spawn do
      begin
        case action
        when "clear-cache"     then handle_clear_cache
        when "cleanup-orphaned" then handle_cleanup_orphaned
        end
      rescue ex
        Log.for("quickheadlines.app").error(exception: ex) { "Admin action error" }
      end
    end

    ATH::Response.new("Admin action started in background", 202, HTTP::Headers{"content-type" => "text/plain"})
  end

  private def handle_clear_cache : Nil
    cache = @feed_cache
    db = cache.db

    feed_count = db.query_one("SELECT COUNT(*) FROM feeds", as: Int64)
    item_count = db.query_one("SELECT COUNT(*) FROM items", as: Int64)

    db.transaction do
      db.exec("DELETE FROM items")
      db.exec("DELETE FROM feeds")
      cache.clear_clustering_metadata
      cache.clear_all
    end

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
    existing_feeds = feed_repo.find_all
    db_urls = existing_feeds.map(&.url).to_set

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
    nil
  rescue JSON::ParseException
    nil
  end

  @[ARTA::Get(path: "/api/status")]
  def status(request : ATH::Request) : ATH::Response
    raise ATH::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

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
    raise ATH::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    body = {
      "updated_at" => StateStore.updated_at.to_unix_ms,
      "clustering" => StateStore.clustering?,
    }.to_json

    ATH::Response.new(body, 200, HTTP::Headers{"content-type" => "application/json"})
  end

end
