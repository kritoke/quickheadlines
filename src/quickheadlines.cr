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

# ----- main -----

# Try to get config path from a named argument (config=...), or positional, or fall back to defaults
config_path = parse_config_arg(ARGV) || find_default_config

unless config_path && File.exists?(config_path)
  STDERR.puts "Config not found."
  STDERR.puts "Provide via: config=PATH or positional PATH, or place feeds.yml in one of:"
  DEFAULT_CONFIG_CANDIDATES.each { |path| STDERR.puts "  - #{path}" }
  exit 1
end

initial_config = load_config(config_path)
state = ConfigState.new(initial_config, file_mtime(config_path))

# Initial load so the first request sees real data
refresh_all(state.config)

# Start periodic refresh
start_refresh_loop(config_path)

# Serve in-memory HTML
start_server(state.config.server_port)
