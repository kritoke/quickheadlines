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
require "./minhash"
require "./elm_js"
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

require "./controllers/api_controller"

require "./events/story_fetched_event"
require "./listeners/heat_map_listener"

require "./dtos/story_dto"
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
  STDERR.puts "[#{Time.local}] Loaded #{FeedCache.instance.size} feeds from cache"

  # Initialize favicon storage directory
  FaviconStorage.init

  # Ensure Elm JS bundles are in sync to avoid serving the wrong file
  begin
    public_path = "./public/elm.js"
    ui_path = "./ui/elm.js"

    if File.exists?(public_path)
      public_content = File.read(public_path)

      if File.exists?(ui_path)
        ui_content = File.read(ui_path)
        if public_content != ui_content
          STDERR.puts "[WARN] Detected mismatch between public/elm.js and ui/elm.js — syncing ui/elm.js from public/elm.js"
          File.write(ui_path, public_content)
        end
      else
        STDERR.puts "[INFO] ui/elm.js not present — creating from public/elm.js to avoid stale bundles being served"
        File.write(ui_path, public_content)
      end
    end
  rescue ex
    STDERR.puts "[WARN] Failed to sync elm.js files: #{ex.message}"
  end

  # Clear in-memory favicon cache to prevent stale base64 data from previous runs
  FAVICON_CACHE.clear

  # Initial load so the first request sees real data
  refresh_all(initial_config)

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
