require "../config"
require "../constants"
require "../storage"
require "./database_service"
require "../websocket"
require "../events/story_fetched_event"
require "../fetcher/vug_adapter"

class AppBootstrap
  @config : Config
  @db_service : DatabaseService
  @feed_cache : FeedCache
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
    @db_service = DatabaseService.new(@config)

    @feed_cache = load_feed_cache(@config, @db_service)
    begin
      @feed_cache.normalize_pub_dates
    rescue ex
      Log.for("quickheadlines.app").warn(exception: ex) { "normalize_pub_dates failed on startup" }
    end
    Log.for("quickheadlines.app").info { "Loaded #{@feed_cache.size} feeds from cache" }

    FaviconStorage.init
    VugAdapter.clear_cache

    cleanup_stale_feeds

    load_feeds_from_cache(@config)

    EventBroadcaster.start
  end

  def initialize_services
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
    Log.for("quickheadlines.app").info { "Verifying feeds loaded..." }
    Log.for("quickheadlines.app").debug { "StateStore.feeds.size=#{StateStore.feeds.size}" }
    StateStore.tabs.each do |tab|
      Log.for("quickheadlines.app").debug { "StateStore.tabs[#{tab.name}].feeds.size=#{tab.feeds.size}" }
    end
  end

  private def start_janitor
    spawn do
      loop do
        sleep @janitor_interval
        begin
          removed = SocketManager.instance.cleanup_dead_connections
          Log.for("quickheadlines.app").debug { "Janitor: #{removed} dead connections cleaned up, #{SocketManager.instance.connection_count} active" }
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Janitor error" }
        end
      end
    end
  end

  private def start_feed_refresh
    spawn do
      start_refresh_loop("feeds.yml", @feed_cache, @db_service)
    end
  end

  private def start_clustering_scheduler
    spawn do
      loop do
        sleep @clustering_interval
        if start_time = StateStore.clustering_start_time
          if Time.utc - start_time > 4.hours
            Log.for("quickheadlines.app").warn { "Clustering stuck for >4 hours, resetting state" }
            StateStore.clustering = false
          end
        end
        next if StateStore.clustering?
        threshold = StateStore.config.try(&.clustering).try(&.threshold) || 0.35
        clustering_service(@db_service).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
      end
    end
  end

  private def run_initial_clustering
    run_on_startup = @config.clustering.try(&.run_on_startup?)
    if run_on_startup.nil? || run_on_startup
      spawn do
        sleep 30.seconds
        begin
          Log.for("quickheadlines.app").info { "Running initial clustering on startup..." }
          threshold = @config.clustering.try(&.threshold) || 0.35
          clustering_service(@db_service).recluster_with_lsh(@feed_cache, @config.db_fetch_limit, threshold)
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Initial clustering failed" }
        end
      end
    end
  end

  private def start_cleanup_scheduler
    spawn do
      loop do
        sleep @cleanup_interval
        begin
          @feed_cache.cleanup_old_articles(QuickHeadlines::Constants::CACHE_RETENTION_DAYS)
          @feed_cache.cleanup_old_entries(@config.cache_retention_hours || QuickHeadlines::Constants::CACHE_RETENTION_HOURS)
          Log.for("quickheadlines.app").debug { "Scheduled cleanup completed" }
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "Scheduled cleanup failed" }
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
          stats = SocketManager.instance.stats
          Log.for("quickheadlines.websocket").debug do
            "Janitor: #{stats["connections"]} active, #{removed} removed, " \
            "#{stats["messages_sent"]} sent, #{stats["messages_dropped"]} dropped, " \
            "#{stats["send_errors"]} errors"
          end
        rescue ex
          Log.for("quickheadlines.websocket").error(exception: ex) { "Janitor failed" }
        end
      end
    end
  end

  private def cleanup_stale_feeds
    config_urls = @config.feeds.map(&.url)
    @config.tabs.each do |tab|
      tab.feeds.each { |feed| config_urls << feed.url }
    end
    @feed_cache.remove_stale_feeds(config_urls)
  rescue ex
    Log.for("quickheadlines.app").warn(exception: ex) { "cleanup_stale_feeds failed on startup" }
  end
end
