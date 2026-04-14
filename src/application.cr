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

require "./domain/items"

require "./services/clustering_service"
require "./services/heat_map_service"
require "./services/database_service"
require "./services/app_bootstrap"

require "./repositories/story_repository"
require "./repositories/feed_repository"
require "./repositories/heat_map_repository"

require "./controllers/api_base_controller"
require "./controllers/cluster_controller"
require "./controllers/feeds_controller"
require "./controllers/feed_pagination_controller"
require "./controllers/config_controller"
require "./controllers/tabs_controller"
require "./controllers/header_color_controller"
require "./controllers/timeline_controller"
require "./controllers/asset_controller"
require "./controllers/proxy_controller"
require "./controllers/admin_controller"

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
  config_result = load_validated_config(QuickHeadlines::CONFIG_PATH)
  unless config_result.success
    Log.for("quickheadlines.app").fatal { "\nFailed to load configuration from feeds.yml:" }
    Log.for("quickheadlines.app").fatal { "  #{config_result.error_message}" }
    if line = config_result.error_line
      Log.for("quickheadlines.app").fatal { "  Line: #{line}, Column: #{config_result.error_column || "unknown"}" }
    end
    if suggestion = config_result.suggestion
      Log.for("quickheadlines.app").fatal { "  Suggestion: #{suggestion}" }
    end
    exit 1
  end

  config = config_result.config.as(Config)

  begin
    validate_feed_urls!(config)
  rescue ex : ConfigValidationError
    Log.for("quickheadlines.app").fatal { "\nFeed URL validation failed:" }
    Log.for("quickheadlines.app").fatal { ex.message.to_s }
    exit 1
  end

  QuickHeadlines::Application.initial_config = config

  bootstrap = AppBootstrap.new(config)
  bootstrap.initialize_services
  QuickHeadlines::Application.bootstrap = bootstrap
rescue ex : Exception
  Log.for("quickheadlines.app").fatal(exception: ex) { "Failed to initialize application" }
  exit 1
end
