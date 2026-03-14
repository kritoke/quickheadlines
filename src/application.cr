require "athena"

# Load all dependencies
require "./config"
require "./constants"
require "./models"
require "./utils"
require "./parser"
require "./fetcher"
require "./storage"
require "./favicon_storage"
require "./health_monitor"
require "./api"
require "./websocket"

# Load entities, services, controllers, repositories, etc.
require "./entities/story"
require "./entities/cluster"
require "./entities/feed"

require "./services/clustering_service"
require "./services/heat_map_service"
require "./services/database_service"
require "./services/app_bootstrap"

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

module QuickHeadlines
  CONFIG_PATH = "feeds.yml"
end

# Initialize application state
begin
  config_result = load_config_with_validation(QuickHeadlines::CONFIG_PATH)
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

  config = config_result.config.as(Config)
  QuickHeadlines::Application.initial_config = config

  bootstrap = AppBootstrap.new(config)
  bootstrap.initialize_services
  bootstrap.start_background_tasks
  bootstrap.verify_feeds_loaded
rescue ex : Exception
  STDERR.puts "[ERROR] Failed to initialize application: #{ex.message}"
  STDERR.puts ex.backtrace.join("\n")
  exit 1
end

# Main entry point
if PROGRAM_NAME == __FILE__
  ATH.run
end
