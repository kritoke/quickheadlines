require "base64"
require "gc"
require "./software_fetcher"
require "./favicon_storage"
require "./health_monitor"
require "./config"
require "./color_extractor"
require "./services/clustering_service"

# Split file: require smaller focused files to reduce per-file complexity
require "./fav"
require "./feed"
require "./cluster"
