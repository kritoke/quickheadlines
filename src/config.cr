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

  # Feed Item Limit (optional, default: 10)
  property item_limit : Int32 = 10

  # Wev Server Port (optional, default: 3030)
  property server_port : Int32 = 3030

  property feeds : Array(Feed) = [] of Feed

  property software_releases : SoftwareConfig?

  property tabs : Array(TabConfig) = [] of TabConfig
end

record ConfigState, config : Config, mtime : Time

def file_mtime(path : String) : Time
  File.info(path).modification_time
end

def load_config(path : String) : Config
  File.open(path) do |io|
    Config.from_yaml(io)
  end
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
