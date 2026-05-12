require "./api_base_controller"
require "../fetcher/refresh_loop"

# Helper struct to bundle WebSocket statistics
private struct WebSocketStats
  property connections : Int32
  property send_errors : Int64
  property closed_total : Int64

  def initialize(
    @connections : Int32 = 0,
    @send_errors : Int64 = 0_i64,
    @closed_total : Int64 = 0_i64
  )
  end

  def self.from_hash(hash : Hash(String, Int32 | Int64)) : self
    new(
      connections: hash["connections"]?.try(&.to_i32) || 0,
      send_errors: hash["send_errors"]?.try(&.to_i64) || 0_i64,
      closed_total: hash["closed_total"]?.try(&.to_i64) || 0_i64
    )
  end
end

# Helper struct to bundle broadcaster statistics
private struct BroadcasterStats
  property sent : Int64
  property dropped : Int64
  property processed : Int64

  def initialize(
    @sent : Int64 = 0_i64,
    @dropped : Int64 = 0_i64,
    @processed : Int64 = 0_i64
  )
  end

  def self.from_hash(hash : Hash(String, Int64)) : self
    new(
      sent: hash["sent"]? || 0_i64,
      dropped: hash["dropped"]? || 0_i64,
      processed: hash["processed"]? || 0_i64
    )
  end
end

class QuickHeadlines::Controllers::AdminController < QuickHeadlines::Controllers::ApiBaseController
  VALID_ADMIN_ACTIONS = {"clear-cache", "cleanup-orphaned"}

  @[ARTA::Post(path: "/api/cluster")]
  def cluster(request : AHTTP::Request) : QuickHeadlines::DTOs::AdminActionResponse
    raise AHK::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    check_rate_limit!(request, "cluster", 1, 60)
    spawn_clustering_task

    QuickHeadlines::DTOs::AdminActionResponse.new(status: "started", message: "Clustering started in background")
  end

  private def spawn_clustering_task : Nil
    spawn do
      start_time = Time.utc
      begin
        run_clustering
        record_cluster_success(start_time)
      rescue ex
        record_cluster_failure(ex, start_time)
      end
    end
  end

  private def run_clustering : Nil
    service = clustering_service
    cluster_limit = cluster_config_limit
    threshold = cluster_config_threshold

    Log.for("quickheadlines.clustering").debug { "Running clustering..." } if debug_mode?
    service.recluster_with_lsh(@feed_cache, cluster_limit, threshold)
  end

  private def cluster_config_limit : Int32
    StateStore.config.try(&.clustering).try(&.max_items) || StateStore.config.try(&.db_fetch_limit) || 5000
  end

  private def cluster_config_threshold : Float64
    StateStore.config.try(&.clustering).try(&.threshold) || 0.35
  end

  private def debug_mode? : Bool
    StateStore.config.try(&.debug?) || false
  end

  private def record_cluster_success(start_time : Time) : Nil
    duration_ms = duration_ms_since(start_time)
    StateStore.set_cluster_completed(duration_ms, "success")
  end

  private def record_cluster_failure(ex : Exception, start_time : Time) : Nil
    duration_ms = duration_ms_since(start_time)
    StateStore.set_cluster_completed(duration_ms, "failed: #{ex.message}")
    Log.for("quickheadlines.clustering").error(exception: ex) { "Clustering error" }
  end

  @[ARTA::Post(path: "/api/admin")]
  def admin(request : AHTTP::Request) : QuickHeadlines::DTOs::AdminActionResponse
    raise AHK::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    check_rate_limit!(request, "admin", 1, 60)

    body_io = request.body
    action = parse_admin_action(body_io)

    raise AHK::Exception::BadRequest.new("Missing action field") unless action
    raise AHK::Exception::BadRequest.new("Unknown action: #{action}") unless action.in?(VALID_ADMIN_ACTIONS)

    spawn_admin_action(action)

    QuickHeadlines::DTOs::AdminActionResponse.new(status: "started", message: "Admin action started in background")
  end

  private def spawn_admin_action(action : String) : Nil
    spawn do
      start_time = Time.utc
      begin
        execute_admin_action(action)
        record_admin_success(action, start_time)
      rescue ex
        record_admin_failure(action, ex, start_time)
      end
    end
  end

  private def execute_admin_action(action : String) : Nil
    case action
    when "clear-cache"      then handle_clear_cache
    when "cleanup-orphaned" then handle_cleanup_orphaned
    end
  end

  private def record_admin_success(action : String, start_time : Time) : Nil
    duration_ms = duration_ms_since(start_time)
    StateStore.set_admin_completed(action, duration_ms, "success")
  end

  private def record_admin_failure(action : String, ex : Exception, start_time : Time) : Nil
    duration_ms = duration_ms_since(start_time)
    StateStore.set_admin_completed(action, duration_ms, "failed: #{ex.message}")
    Log.for("quickheadlines.app").error(exception: ex) { "Admin action error" }
  end

  private def duration_ms_since(start_time : Time) : Int64
    (Time.utc - start_time).total_milliseconds.to_i64
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

    config_urls = collect_config_feed_urls
    feed_repo = QuickHeadlines::Repositories::FeedRepository.new(@db_service)
    db_urls = feed_repo.find_all_urls

    orphaned = db_urls - config_urls
    return if orphaned.empty?

    perform_cleanup(db, orphaned)
    Log.for("quickheadlines.app").info { "Cleaned up #{orphaned.size} orphaned feeds" }
  end

  private def collect_config_feed_urls : Set(String)
    urls = Set(String).new
    StateStore.feeds.each { |feed| urls << feed.url }
    StateStore.tabs.each { |tab| tab.feeds.each { |feed| urls << feed.url } }
    urls
  end

  private def perform_cleanup(db, orphaned : Set(String)) : Nil
    placeholders = QuickHeadlines::Repositories::RepositoryBase.placeholders(orphaned.size)
    deleted_items = db.exec(
      "DELETE FROM items WHERE feed_id IN (SELECT id FROM feeds WHERE url IN (#{placeholders}))",
      args: orphaned.to_a
    ).rows_affected

    db.exec("DELETE FROM feeds WHERE url IN (#{placeholders})", args: orphaned.to_a)

    cluster_repo = QuickHeadlines::Repositories::ClusterRepository.new(@db_service)
    cluster_repo.clear_all_metadata
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

    ws_stats = WebSocketStats.from_hash(@socket_manager.stats)
    broadcaster_stats = BroadcasterStats.from_hash(EventBroadcaster.stats)
    admin_state = build_admin_state

    QuickHeadlines::DTOs::AdminStatusResponse.new(
      clustering: StateStore.clustering?,
      refreshing: StateStore.refreshing?,
      active_jobs: 0,
      websocket_connections: ws_stats.connections,
      websocket_messages_sent: broadcaster_stats.sent,
      websocket_messages_dropped: broadcaster_stats.dropped,
      websocket_send_errors: ws_stats.send_errors,
      websocket_connections_closed: ws_stats.closed_total,
      broadcaster_processed: broadcaster_stats.processed,
      last_cluster_run: StateStore.last_cluster_run.try(&.to_unix_ms),
      last_cluster_duration_ms: StateStore.last_cluster_duration_ms,
      last_cluster_status: StateStore.last_cluster_status,
      last_admin_action: StateStore.last_admin_action,
      last_admin_run: StateStore.last_admin_run.try(&.to_unix_ms),
      last_admin_duration_ms: StateStore.last_admin_duration_ms,
      last_admin_status: StateStore.last_admin_status,
    )
  end

  private def build_admin_state : NamedTuple(
    last_cluster_run: Int64?,
    last_cluster_duration_ms: Int64?,
    last_cluster_status: String?,
    last_admin_action: String?,
    last_admin_run: Int64?,
    last_admin_duration_ms: Int64?,
    last_admin_status: String?
  )
    {
      last_cluster_run: StateStore.last_cluster_run.try(&.to_unix_ms),
      last_cluster_duration_ms: StateStore.last_cluster_duration_ms,
      last_cluster_status: StateStore.last_cluster_status,
      last_admin_action: StateStore.last_admin_action,
      last_admin_run: StateStore.last_admin_run.try(&.to_unix_ms),
      last_admin_duration_ms: StateStore.last_admin_duration_ms,
      last_admin_status: StateStore.last_admin_status,
    }
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
