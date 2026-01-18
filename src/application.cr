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

# Load entities, services, controllers, repositories, etc.
require "./entities/story"
require "./entities/cluster"
require "./entities/feed"

require "./services/clustering_service"
require "./services/heat_map_service"

require "./repositories/story_repository"
require "./repositories/feed_repository"
require "./repositories/heat_map_repository"

require "./controllers/story_controller"
require "./controllers/feed_controller"

require "./events/story_fetched_event"
require "./listeners/heat_map_listener"

require "./dtos/story_dto"
require "./dtos/cluster_dto"
require "./dtos/feed_dto"

# Main entry point
if PROGRAM_NAME == __FILE__
  ATH.run
end
