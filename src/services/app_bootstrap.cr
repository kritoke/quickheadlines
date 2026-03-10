require "../config"
require "../constants"
require "../storage"
require "./database_service"
require "../websocket"
require "../events/story_fetched_event"

class AppBootstrap
  @config : Config
  @janitor_interval : Time::Span
  @clustering_interval : Time::Span
  @cleanup_interval : Time::Span
  @ws_janitor_interval : Time::Span

  def initialize(
    @config : Config,
    @janitor_interval = 60.seconds,
    @clustering_interval = 60.minutes,
    @cleanup_interval = 6.hours,
    @ws_janitor_interval = 5.minutes,
  )
  end

  def initialize_services
    db_service = DatabaseService.new(@config)
    DatabaseService.instance = db_service

    FeedCache.instance = load_feed_cache(@config)
    begin
      FeedCache.instance.normalize_pub_dates
    rescue ex
      STDERR.puts "[#{Time.local}] Warning: normalize_pub_dates failed on startup: #{ex.message}"
    end
    STDERR.puts "[#{Time.local}] Loaded #{FeedCache.instance.size} feeds from cache"

    FaviconStorage.init
    FAVICON_CACHE.clear

    load_feeds_from_cache(@config)

    EventBroadcaster.start
  end

  def start_background_tasks
    start_janitor
    start_feed_refresh
    start_clustering_scheduler
    start_cleanup_scheduler
    start_ws_janitor
    run_initial_clustering
  end

  def verify_feeds_loaded
    STDERR.puts "[#{Time.local}] Verifying feeds loaded..."
    STDERR.puts "[#{Time.local}] STATE.feeds.size=#{STATE.feeds.size}"
    STATE.tabs.each do |tab|
      STDERR.puts "[#{Time.local}] STATE.tabs[#{tab.name}].feeds.size=#{tab.feeds.size}"
    end
  end

  private def start_janitor
    spawn do
      loop do
        sleep @janitor_interval
        begin
          removed = SocketManager.instance.cleanup_dead_connections
          STDERR.puts "[#{Time.local}] Janitor: #{removed} dead connections cleaned up, #{SocketManager.instance.connection_count} active"
        rescue ex
          STDERR.puts "[#{Time.local}] Janitor error: #{ex.message}"
        end
      end
    end
  end

  private def start_feed_refresh
    spawn do
      start_refresh_loop("feeds.yml")
    end
  end

  private def start_clustering_scheduler
    spawn do
      loop do
        sleep @clustering_interval
        next if STATE.clustering?
        threshold = STATE.config.try(&.clustering).try(&.threshold) || 0.35
        clustering_service.recluster_with_lsh(@config.db_fetch_limit, threshold)
      end
    end
  end

  private def run_initial_clustering
    run_on_startup = @config.clustering.try(&.run_on_startup?)
    if run_on_startup.nil? || run_on_startup
      spawn do
        sleep 30.seconds
        begin
          STDERR.puts "[#{Time.local}] Running initial clustering on startup..."
          threshold = @config.clustering.try(&.threshold) || 0.35
          clustering_service.recluster_with_lsh(@config.db_fetch_limit, threshold)
        rescue ex
          STDERR.puts "[#{Time.local}] Initial clustering failed: #{ex.message}"
        end
      end
    end
  end

  private def start_cleanup_scheduler
    spawn do
      loop do
        sleep @cleanup_interval
        begin
          cache = FeedCache.instance
          cache.cleanup_old_articles(Constants::CACHE_RETENTION_DAYS)
          cache.cleanup_old_entries(@config.cache_retention_hours || Constants::CACHE_RETENTION_HOURS)
          STDERR.puts "[#{Time.local}] Scheduled cleanup completed"
        rescue ex
          STDERR.puts "[#{Time.local}] Scheduled cleanup failed: #{ex.message}"
        end
      end
    end
  end

  private def start_ws_janitor
    spawn do
      loop do
        sleep @ws_janitor_interval
        begin
          removed = SocketManager.instance.cleanup_dead_connections
          stats = SocketManager.instance.get_stats
          STDERR.puts "[WebSocket] Janitor: #{stats["connections"]} active, #{removed} removed, " \
                      "#{stats["messages_sent"]} sent, #{stats["messages_dropped"]} dropped, " \
                      "#{stats["send_errors"]} errors"
        rescue ex
          STDERR.puts "[WebSocket] Janitor failed: #{ex.message}"
        end
      end
    end
  end
end
