require "yaml"

struct Feed
  include YAML::Serializable

  property title : String
  property url : String
  property header_color : String?
  property header_text_color : String?

  property item_limit : Int32? = nil
end

struct SoftwareConfig
  include YAML::Serializable
  property title : String = "Software Updates"
  property header_color : String?
  property header_text_color : String?
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

  property? debug : Bool = false
  property refresh_minutes : Int32 = 10
  property page_title : String = "Quick Headlines"
  property item_limit : Int32 = 20
  property db_fetch_limit : Int32 = 500
  property server_port : Int32 = 3030
  property timeline_batch_size : Int32 = 30
  property cache_dir : String?
  property cache_retention_hours : Int32 = 336
  property max_cache_size_mb : Int32 = 100
  property feeds : Array(Feed) = [] of Feed
  property software_releases : SoftwareConfig?
  property tabs : Array(TabConfig) = [] of TabConfig
  property clustering : ClusteringConfig? = nil

  def all_feed_urls : Array(String)
    urls = feeds.map(&.url)
    tabs.each do |tab|
      urls.concat(tab.feeds.map(&.url))
    end
    urls
  end
end

struct ClusteringConfig
  include YAML::Serializable

  @[YAML::Field(key: "enabled")]
  private property _enabled : Bool = true

  def enabled? : Bool
    _enabled
  end

  property schedule_minutes : Int32 = 60

  @[YAML::Field(key: "run_on_startup")]
  private property _run_on_startup : Bool = true

  def run_on_startup? : Bool
    _run_on_startup
  end

  property max_items : Int32? = nil
  property max_fetch_items : Int32 = 1000
  property threshold : Float64 = 0.35
end

record ConfigLoadResult,
  success : Bool,
  config : Config?,
  error_message : String?,
  error_line : Int32?,
  error_column : Int32?,
  suggestion : String?

enum DbHealthStatus
  Healthy
  Corrupted
  Repaired
  NeedsRepopulation
end

record DbRepairResult,
  status : DbHealthStatus,
  backup_path : String?,
  repair_time : Time
