require "yaml"
require "http/server"
require "http/client"
require "xml"
require "slang"
require "html"
require "gc"
require "uri"
require "base64"

require "./config"
require "./models"
require "./utils"
require "./parser"
require "./fetcher"
require "./server"
require "./storage"
require "./favicon_storage"

# ----- main -----

# Try to get config path from a named argument (config=...), or positional, or fall back to defaults
config_path = parse_config_arg(ARGV) || find_default_config

# If no config found, try to download from GitHub
unless config_path && File.exists?(config_path)
  # Try to download from GitHub to default location
  target_path = "feeds.yml"

  unless download_config_from_github(target_path)
    # Download was not attempted (no GitHub repo detected)
    # If download was attempted, specific error was already shown
    unless File.exists?(target_path)
      STDERR.puts "\nConfig not found."
      STDERR.puts "Provide via: config=PATH or positional PATH, or place feeds.yml in one of:"
      DEFAULT_CONFIG_CANDIDATES.each { |path| STDERR.puts "  - #{path}" }
      STDERR.puts "\nOr ensure you're in a git repository with GitHub origin remote to auto-download."
      exit 1
    end
  end

  config_path = target_path
end

initial_config = load_config(config_path)
state = ConfigState.new(initial_config, file_mtime(config_path))

# Load feed cache from disk (creates SQLite connection)
FeedCache.instance = load_feed_cache(initial_config)
puts "[#{Time.local}] Loaded #{FeedCache.instance.size} feeds from cache"

# Initialize favicon storage directory
FaviconStorage.init

# Initial load so the first request sees real data
refresh_all(state.config)

# Start periodic refresh
start_refresh_loop(config_path)

# Serve in-memory HTML
start_server(state.config.server_port)
