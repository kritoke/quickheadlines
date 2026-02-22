require "athena"

# Load all dependencies
require "./config"
require "./models"
require "./utils"
require "./parser"
require "./fetcher"
require "./storage"
require "./favicon_storage"
require "./health_monitor"
require "./api"

# Load entities, services, controllers, repositories, etc.
require "./entities/story"
require "./entities/cluster"
require "./entities/feed"

require "./services/clustering_service"
require "./services/heat_map_service"
require "./services/database_service"

require "./repositories/story_repository"
require "./repositories/feed_repository"
require "./repositories/heat_map_repository"

require "./rate_limiter"
require "./controllers/api_controller"

# Svelte frontend with baked assets
require "./web/assets"
require "./web/static_controller"

require "./events/story_fetched_event"
require "./listeners/heat_map_listener"

require "./dtos/story_dto"
require "./dtos/status_dto"
require "./dtos/cluster_dto"
require "./dtos/feed_dto"

# Initialize application state
begin
  # Load configuration
  config_result = load_config_with_validation("feeds.yml")
  unless config_result.success
    STDERR.puts "\n[ERROR] Failed to load configuration from feeds.yml:"
    STDERR.puts "  #{config_result.error_message}"
    if line = config_result.error_line
      STDERR.puts "  Line: #{line}, Column: #{config_result.error_column || "unknown"}"
    end
    if suggestion = config_result.suggestion
      STDERR.puts "  Suggestion: #{suggestion}"
    end
    exit 1
  end

  initial_config = config_result.config.as(Config)

  # Initialize database service with dependency injection
  db_service = DatabaseService.new(initial_config)
  DatabaseService.instance = db_service

  # Load feed cache from disk (creates SQLite connection)
  FeedCache.instance = load_feed_cache(initial_config)
  # Normalize any non-canonical pub_date values on startup to fix legacy or
  # mixed-format timestamps. This runs once at startup to fix stored data.
  begin
    FeedCache.instance.normalize_pub_dates
  rescue ex
    STDERR.puts "[#{Time.local}] Warning: normalize_pub_dates failed on startup: #{ex.message}"
  end
  STDERR.puts "[#{Time.local}] Loaded #{FeedCache.instance.size} feeds from cache"

  # Initialize favicon storage directory
  FaviconStorage.init

  # Clear in-memory favicon cache to prevent stale base64 data from previous runs
  FAVICON_CACHE.clear

  # Load from cache first so server can respond immediately
  load_feeds_from_cache(initial_config)

  # Start background refresh loop for automatic feed updates
  spawn do
    start_refresh_loop("feeds.yml")
  end

  # Clustering scheduler
  spawn do
    loop do
      sleep 60.minutes
      next if STATE.is_clustering?
      threshold = STATE.config.try(&.clustering).try(&.threshold) || 0.35
      clustering_service.recluster_with_lsh(initial_config.db_fetch_limit, threshold)
    end
  end

  # Old articles cleanup scheduler - runs every 6 hours
  spawn do
    loop do
      sleep 6.hours
      begin
        cache = FeedCache.instance
        cache.cleanup_old_articles(CACHE_RETENTION_DAYS)
        cache.cleanup_old_entries(initial_config.cache_retention_hours || CACHE_RETENTION_HOURS)
        STDERR.puts "[#{Time.local}] Scheduled cleanup completed"
      rescue ex
        STDERR.puts "[#{Time.local}] Scheduled cleanup failed: #{ex.message}"
      end
    end
  end

  # Verify feeds are loaded before starting server
  STDERR.puts "[#{Time.local}] Verifying feeds loaded..."
  STDERR.puts "[#{Time.local}] STATE.feeds.size=#{STATE.feeds.size}"
  STATE.tabs.each do |tab|
    STDERR.puts "[#{Time.local}] STATE.tabs[#{tab.name}].feeds.size=#{tab.feeds.size}"
  end
rescue ex : Exception
  STDERR.puts "[ERROR] Failed to initialize application: #{ex.message}"
  STDERR.puts ex.backtrace.join("\n")
  exit 1
end

# Main entry point
if PROGRAM_NAME == __FILE__
  ATH.run
end
