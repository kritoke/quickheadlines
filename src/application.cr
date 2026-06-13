require "athena"

require "./module"

# GC tuning: configure Boehm GC to return freed memory to the OS.
# Without these, RSS grows monotonically because Boehm GC keeps
# freed pages mapped. These env vars are read by libgc at init time.
#   GC_MAXIMUM_HEAP_SIZE — hard cap on heap growth (bytes, 0=unlimited)
#   GC_UNMAP_THRESHOLD   — pages unmapped after N GC cycles (0=never, 1=immediate)
#   GC_FREE_SPACE_DIVISOR — higher = more aggressive collection
# Set via environment before process start, or programmatically here.
# The values below target ~512MB max heap with aggressive unmapping.
{% unless env("GC_MAXIMUM_HEAP_SIZE") %}
  # LibGC functions are available via the boehm-crystal binding
  # GC_set_max_heap_size is called after GC_init (which happens at
  # Crystal runtime startup). We call it early in application.cr
  # to limit heap growth before heavy allocations begin.
  lib LibGC
    fun GC_set_max_heap_size(bytes : LibC::ULong)
    fun GC_get_free_space_divisor : LibC::Int
    fun GC_set_free_space_divisor(divisor : LibC::Int)
  end
{% end %}

# Load all dependencies
require "./config"
require "./constants"
require "./models"
require "./utils"
require "./fetcher"
require "./storage"
require "./favicon_storage"
require "./favicon_cache"
require "./websocket"

# Load entities, services, controllers, repositories, etc.
require "./entities/story"
require "./entities/cluster"

require "./services/clustering_service"
require "./services/database_service"
require "./services/app_bootstrap"
require "./services/feed_service"

require "./repositories/story_repository"
require "./repositories/feed_repository"

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
require "./controllers/content_controller"

# Svelte frontend with baked assets
require "./web/assets"
require "./web/static_controller"

require "./dtos/story_dto"
require "./dtos/cluster_dto"

module QuickHeadlines
  CONFIG_PATH = "feeds.yml"
end

# Apply GC tuning early, before heavy allocations.
# These calls are safe after Crystal's runtime init (which calls GC_init).
{% unless env("GC_MAXIMUM_HEAP_SIZE") %}
  begin
    # Cap heap at 512MB. When exceeded, GC will collect aggressively
    # and unmap freed pages back to the OS.
    LibGC.GC_set_max_heap_size(512_u64 * 1024_u64 * 1024_u64)
    # Higher divisor = more aggressive collection (default is 3)
    LibGC.GC_set_free_space_divisor(8)
    Log.for("quickheadlines.gc").info { "GC tuning applied: max_heap=512MB, free_space_divisor=8" }
  rescue ex
    Log.for("quickheadlines.gc").warn { "GC tuning failed: #{ex.message}" }
  end
{% end %}

# Initialize application state
begin
  config_result = ConfigLoader.load_validated_config(QuickHeadlines::CONFIG_PATH)
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
    ConfigValidator.validate_feed_urls!(config)
  rescue ex : QuickHeadlines::ConfigValidationError
    Log.for("quickheadlines.app").fatal { "\nFeed URL validation failed:" }
    Log.for("quickheadlines.app").fatal { ex.message.to_s }
    exit 1
  end

  QuickHeadlines.initial_config = config

  bootstrap = AppBootstrap.new(config)
  QuickHeadlines.bootstrap = bootstrap

  Log.for("quickheadlines.app").info { "Synchronously loading feeds from cache..." }
  FeedFetcher.load_feeds_from_cache(config)
  Log.for("quickheadlines.app").info { "StateStore pre-loaded with #{StateStore.feeds.size} feeds and #{StateStore.tabs.size} tabs" }
rescue ex : Exception
  Log.for("quickheadlines.app").fatal(exception: ex) { "Failed to initialize application" }
  exit 1
end
