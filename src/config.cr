require "yaml"
require "http/client"
require "process"

DEFAULT_CONFIG_CANDIDATES = [
  "feeds.yml",
  "config/feeds.yml",
  "feeds.yaml",
  "config/feeds.yaml",
]

struct Feed
  include YAML::Serializable

  property title : String
  property url : String
  property header_color : String?

  # Retry and timeout configuration
  property max_retries : Int32 = 3 # Number of retry attempts on failure
  property retry_delay : Int32 = 5 # Base delay between retries (seconds)
  property timeout : Int32 = 30    # Request timeout (seconds)

  # Feed-specific item limit (nil = use global default)
  property item_limit : Int32? = nil

  # Feed-specific authentication
  property auth : AuthConfig? = nil
end

# HTTP client configuration for global settings
struct HttpClientConfig
  include YAML::Serializable

  # Connection timeout in seconds (default: 10)
  property connect_timeout : Int32 = 10

  # Read timeout in seconds (default: 30)
  property timeout : Int32 = 30

  # Maximum redirects to follow (default: 10)
  property max_redirects : Int32 = 10

  # Custom User-Agent header (default: QuickHeadlines/version)
  property user_agent : String = "QuickHeadlines/0.3"

  # HTTP proxy URL (optional)
  property proxy : String? = nil
end

# Authentication configuration for feeds
struct AuthConfig
  include YAML::Serializable

  # Authentication type: "basic", "bearer", or "apikey"
  property type : String = "basic"

  # Username for Basic auth (optional)
  property username : String? = nil

  # Password for Basic auth (optional)
  property password : String? = nil

  # Token for Bearer or API Key auth (optional)
  property token : String? = nil

  # Custom header name (default: "Authorization")
  property header : String = "Authorization"

  # Header value prefix (e.g., "Bearer " for Bearer tokens)
  property prefix : String = ""
end

struct SoftwareConfig
  include YAML::Serializable
  property title : String = "Software Updates"
  property header_color : String?
  property repos : Array(String)
end

struct TabConfig
  include YAML::Serializable
  property name : String
  property feeds : Array(Feed) = [] of Feed
  property software_releases : SoftwareConfig?
end

struct Config
  include YAML::Serializable

  # Global refresh interval in minutes (default: 10)
  property refresh_minutes : Int32 = 10

  # Page title (optional, default: Quick Headlines)
  property page_title : String = "Quick Headlines"

  # Feed Item Limit (optional, default: 100 - increased for better story grouping)
  property item_limit : Int32 = 100

  # Web Server Port (optional, default: 3030)
  property server_port : Int32 = 3030

  # Timeline mode batch size for infinite scroll (optional, default: 30)
  property timeline_batch_size : Int32 = 30

  # Cache directory path (optional, defaults to XDG cache or ./cache)
  property cache_dir : String?

  # Cache retention period in hours (default: 168 = 1 week)
  property cache_retention_hours : Int32 = 168

  # HTTP client configuration (optional)
  property http_client : HttpClientConfig? = nil

  property feeds : Array(Feed) = [] of Feed

  property software_releases : SoftwareConfig?

  property tabs : Array(TabConfig) = [] of TabConfig
end

# YAML parsing result with detailed error information
record ConfigLoadResult,
  success : Bool,
  config : Config?,
  error_message : String?,
  error_line : Int32?,
  error_column : Int32?,
  suggestion : String?

# Feed timeout configuration
record FeedTimeoutConfig,
  default_timeout : Int32 = 30,
  slow_feed_timeout : Int32 = 60,
  timeout_multiplier : Float64 = 2.0,
  max_retries_on_timeout : Int32 = 2

# Feed health tracking
enum FeedHealthStatus
  Healthy
  Slow
  Timeout
  Unreachable
end

record FeedHealth,
  url : String,
  status : FeedHealthStatus,
  last_success : Time?,
  last_failure : Time?,
  consecutive_failures : Int32,
  average_response_time : Float64

# Database health status enum
enum DbHealthStatus
  Healthy
  Corrupted
  Repaired
  NeedsRepopulation
end

# Database repair result
record DbRepairResult,
  status : DbHealthStatus,
  backup_path : String?,
  repair_time : Time,
  feeds_to_restore : Int32,
  items_to_restore : Int32

# Feed restoration configuration
record FeedRestoreConfig,
  timeframe_hours : Int32 = 168,
  force_full_refresh : Bool = false,
  restore_on_startup : Bool = true

record ConfigState, config : Config, mtime : Time

def file_mtime(path : String) : Time
  File.info(path).modification_time
end

def load_config(path : String) : Config
  config = File.open(path) do |io|
    Config.from_yaml(io)
  end

  # Validate feeds and log warnings for invalid configurations
  # (result is logged but not used - validation errors are printed to stderr)
  validate_config_feeds(config)

  config
end

def find_default_config : String?
  DEFAULT_CONFIG_CANDIDATES.find { |path| File.exists?(path) }
end

def parse_config_arg(args : Array(String)) : String?
  if arg = args.find(&.starts_with?("config="))
    return arg.split("=", 2)[1]
  end

  if args.size >= 1 && !args[0].includes?("=")
    return args[0]
  end

  nil
end

# Enhanced YAML loading with detailed error handling
def load_config_with_validation(path : String) : ConfigLoadResult
  begin
    # Check file encoding and read content
    content = File.read(path)

    # Remove BOM if present (UTF-8 BOM: \uFEFF)
    if content.starts_with?("\uFEFF")
      content = content[1..-1]
    end

    # Validate YAML structure before parsing
    validate_yaml_structure(content)

    # Parse YAML
    config = Config.from_yaml(content)

    # Validate feeds and log warnings
    validate_config_feeds(config)

    ConfigLoadResult.new(
      success: true,
      config: config,
      error_message: nil,
      error_line: nil,
      error_column: nil,
      suggestion: nil
    )
  rescue ex : YAML::ParseException
    # Extract line and column from error message
    error_msg = ex.message || "Unknown YAML parsing error"

    # Parse error location
    error_line = nil
    error_column = nil

    if error_msg =~ /at line (\d+), column (\d+)/
      error_line = $1.to_i
      error_column = $2.to_i
    end

    # Provide helpful suggestions
    suggestion = suggest_yaml_fix(error_msg, error_line)

    ConfigLoadResult.new(
      success: false,
      config: nil,
      error_message: error_msg,
      error_line: error_line,
      error_column: error_column,
      suggestion: suggestion
    )
  rescue ex : File::Error
    ConfigLoadResult.new(
      success: false,
      config: nil,
      error_message: "Cannot read config file: #{ex.message}",
      error_line: nil,
      error_column: nil,
      suggestion: "Check file permissions and path"
    )
  rescue ex
    ConfigLoadResult.new(
      success: false,
      config: nil,
      error_message: "Unexpected error: #{ex.message}",
      error_line: nil,
      error_column: nil,
      suggestion: "Check file format and encoding"
    )
  end
end

# Validate YAML structure before parsing
private def validate_yaml_structure(content : String) : Nil
  # Check for common YAML issues
  lines = content.lines

  lines.each_with_index do |line, index|
    line_num = index + 1

    # Check for tabs (YAML requires spaces)
    if line.includes?("\t")
      raise YAML::ParseException.new("Line #{line_num}: Contains tab character (use spaces instead)", line_num, 1)
    end

    # Check for trailing whitespace
    if line.rstrip != line
      STDERR.puts "[WARN] Line #{line_num}: Trailing whitespace detected"
    end

    # Check for mixed indentation
    if line =~ /^(\s+)/
      indent = $1
      if indent.includes?("\t")
        raise YAML::ParseException.new("Line #{line_num}: Mixed tabs and spaces in indentation", line_num, 1)
      end
    end
  end
end

# Provide helpful suggestions based on error type
private def suggest_yaml_fix(error_msg : String, error_line : Int32?) : String?
  case error_msg
  when /cannot start any token/
    "Check for invalid characters, missing quotes, or incorrect indentation at line #{error_line}"
  when /mapping values are not allowed/
    "Check for missing colon or incorrect list syntax at line #{error_line}"
  when /did not find expected key/
    "Check for inconsistent indentation or missing key at line #{error_line}"
  when /unexpected character/
    "Check for special characters that need quotes at line #{error_line}"
  else
    "Check YAML syntax at line #{error_line}. Ensure proper indentation and no trailing spaces"
  end
end

# Validate a single feed configuration
def validate_feed(feed : Feed) : Bool
  return false unless valid_url?(feed)
  return false unless valid_item_limit?(feed)
  return false unless valid_retry_config?(feed)
  valid_auth_config?(feed)
end

# Validate feed URL
private def valid_url?(feed : Feed) : Bool
  url = feed.url

  # Check for nil or empty URL
  return false if url.nil? || url.empty?

  # Check for valid URL format
  unless url.starts_with?("http")
    STDERR.puts "[WARN] Invalid feed URL (must start with http/https): #{url}"
    return false
  end

  # Validate URL can be parsed
  begin
    uri = URI.parse(url)
    host = uri.host
    if host.nil? || host.strip.empty?
      STDERR.puts "[WARN] Invalid feed URL (missing host): #{url}"
      return false
    end
  rescue ex
    STDERR.puts "[WARN] Invalid feed URL (parse error): #{url}"
    return false
  end

  true
end

# Validate feed item_limit
private def valid_item_limit?(feed : Feed) : Bool
  limit = feed.item_limit
  return true unless limit

  if limit < 1
    STDERR.puts "[WARN] Invalid item_limit for '#{feed.title}' (must be >= 1), using global default"
    return false
  elsif limit > 100
    STDERR.puts "[WARN] High item_limit for '#{feed.title}' (#{limit}), may impact performance"
  end

  true
end

# Validate retry and timeout configuration
private def valid_retry_config?(feed : Feed) : Bool
  if feed.max_retries < 0 || feed.max_retries > 10
    STDERR.puts "[WARN] Invalid max_retries for '#{feed.title}' (0-10), using default"
  end

  if feed.retry_delay < 1 || feed.retry_delay > 60
    STDERR.puts "[WARN] Invalid retry_delay for '#{feed.title}' (1-60s), using default"
  end

  if feed.timeout < 5 || feed.timeout > 120
    STDERR.puts "[WARN] Invalid timeout for '#{feed.title}' (5-120s), using default"
  end

  true
end

# Validate authentication configuration
private def valid_auth_config?(feed : Feed) : Bool
  auth = feed.auth
  return true unless auth

  # Validate auth type
  valid_types = ["basic", "bearer", "apikey"]
  unless valid_types.includes?(auth.type)
    STDERR.puts "[WARN] Invalid auth type for '#{feed.title}' (must be: basic, bearer, apikey), ignoring auth"
    return true # Warning only, don't fail validation
  end

  # Validate Basic auth requires username and password
  if auth.type == "basic"
    username = auth.username
    if username.nil? || username.strip.empty?
      STDERR.puts "[WARN] Basic auth for '#{feed.title}' missing username"
    end
    password = auth.password
    if password.nil? || password.strip.empty?
      STDERR.puts "[WARN] Basic auth for '#{feed.title}' missing password"
    end
  end

  # Validate Bearer/API Key auth requires token
  if auth.type == "bearer" || auth.type == "apikey"
    token = auth.token
    if token.nil? || token.strip.empty?
      STDERR.puts "[WARN] #{auth.type.capitalize} auth for '#{feed.title}' missing token"
    end
  end

  true
end

# Validate all feeds in a configuration and log warnings
def validate_config_feeds(config : Config) : Array(Feed)
  valid_feeds = [] of Feed

  # Validate top-level feeds
  config.feeds.each do |feed|
    if validate_feed(feed)
      valid_feeds << feed
    else
      STDERR.puts "[WARN] Skipping invalid feed: #{feed.title} (#{feed.url})"
    end
  end

  # Validate tab feeds
  config.tabs.each do |tab|
    tab.feeds.each do |feed|
      if validate_feed(feed)
        valid_feeds << feed
      else
        STDERR.puts "[WARN] Skipping invalid feed in tab '#{tab.name}': #{feed.title} (#{feed.url})"
      end
    end
  end

  valid_feeds
end

# Detect GitHub repository from git remote
def detect_github_repo : String?
  begin
    # Get the origin remote URL
    process = Process.new("git", ["remote", "get-url", "origin"],
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Pipe)

    # Read output BEFORE waiting (stream closes after wait)
    url = process.output.gets_to_end.strip

    if process.wait.success?
      # Parse GitHub URL (both HTTPS and SSH formats)
      if url =~ %r{github.com[/:]([^/]+)/([^/.]+?)(\.git)?$}
        owner = $1
        repo = $2
        return "#{owner}/#{repo}"
      end
    end
  rescue ex
    # Silently fail if git is not available or not in a git repo
  end

  nil
end

# Fetch feeds.yml from GitHub repository
def fetch_config_from_github(repo_path : String, branch : String = "main") : String?
  url = "https://raw.githubusercontent.com/#{repo_path}/#{branch}/feeds.yml"

  begin
    response = HTTP::Client.get(url)
    if response.status_code == 200
      return response.body
    elsif response.status_code == 404 && branch == "main"
      # Try master as fallback
      return fetch_config_from_github(repo_path, "master")
    end
  rescue ex
    STDERR.puts "Error fetching config from GitHub: #{ex.message}"
  end

  nil
end

# Download and save feeds.yml from GitHub
def download_config_from_github(target_path : String) : Bool
  # Detect GitHub repository
  if repo_path = detect_github_repo
    if yaml_content = fetch_config_from_github(repo_path)
      begin
        # Validate YAML before saving
        Config.from_yaml(yaml_content)

        # Save to file
        File.write(target_path, yaml_content)
        STDERR.puts "[#{Time.local}] Auto-downloaded feeds.yml from GitHub (#{repo_path})"
        return true
      rescue ex : YAML::ParseException
        STDERR.puts "Error: Invalid YAML in downloaded feeds.yml: #{ex.message}"
      rescue ex : File::Error
        STDERR.puts "Error: Cannot write feeds.yml to #{target_path}: #{ex.message}"
      rescue ex
        STDERR.puts "Error: Failed to save feeds.yml: #{ex.message}"
      end
    else
      STDERR.puts "Error: Could not fetch feeds.yml from GitHub (file may not exist in repository)"
    end
  else
    STDERR.puts "Error: Could not detect GitHub repository (not in a git repo or no origin remote)"
  end

  false
end
