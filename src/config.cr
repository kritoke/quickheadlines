require "yaml"

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
