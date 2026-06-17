require "athena"
require "mutex"
require "./services/task_metadata"

record Item, title : String, link : String, pub_date : Time?, content : String? = nil, version : String? = nil, comment_url : String? = nil, commentary_url : String? = nil

record ClusteringItemRow,
  id : Int64,
  title : String,
  link : String,
  pub_date : Time?,
  feed_url : String,
  feed_title : String,
  feed_link : String = "",
  favicon : String? = nil,
  favicon_data : String? = nil,
  header_color : String? = nil,
  header_text_color : String? = nil,
  comment_url : String? = nil,
  commentary_url : String? = nil

record FeedData,
  title : String, url : String, site_link : String,
  header_color : String?, header_text_color : String?,
  items : Array(Item), etag : String? = nil, last_modified : String? = nil,
  favicon : String? = nil, favicon_data : String? = nil,
  error_message : String? = nil, header_theme_colors : String? = nil do
  def display_link
    site_link.empty? ? url : site_link
  end

  # Immutable setter - returns new instance
  def with_theme_colors(val : String?) : FeedData
    copy_with(header_theme_colors: val)
  end

  def failed?
    error_message != nil
  end
end

record Tab,
  name : String,
  feeds : Array(FeedData) = [] of FeedData,
  software_releases : Array(FeedData) = [] of FeedData

# Immutable state record for functional updates
record AppStateSnapshot,
  feeds : Array(FeedData),
  tabs : Array(Tab),
  updated_at : Time,
  config_title : String,
  config : Config?,
  clustering : Bool,
  refreshing : Bool

# Thread-safe state store facade that delegates to AppStateService.
# Backward-compatible API: callers continue using StateStore.feeds, StateStore.tabs, etc.
# State is managed by AppStateService, wired by AppBootstrap at startup.
module StateStore
  @@service : QuickHeadlines::Services::AppStateService?

  # Set by AppBootstrap during initialization
  def self.service=(value : QuickHeadlines::Services::AppStateService)
    @@service = value
  end

  private def self.service : QuickHeadlines::Services::AppStateService
    @@service || raise "AppStateService not initialized. AppBootstrap must call StateStore.service= first."
  end

  def self.get : AppStateSnapshot
    service.get
  end

  def self.update(&transform : AppStateSnapshot -> AppStateSnapshot) : AppStateSnapshot
    service.update(&transform)
  end

  def self.memory_history_summary : String
    service.memory_history_summary
  end

  def self.memory_growth_rate : String
    service.memory_growth_rate
  end

  def self.feeds
    service.feeds
  end

  def self.tabs
    service.tabs
  end

  def self.updated_at
    service.updated_at
  end

  def self.config
    service.config
  end

  def self.config_title
    service.config_title
  end

  def self.clustering? : Bool
    service.clustering?
  end

  def self.clustering=(value : Bool)
    service.set_clustering(value)
  end

  def self.start_clustering_if_idle : Bool
    service.start_clustering_if_idle
  end

  def self.refreshing? : Bool
    service.refreshing?
  end

  def self.refreshing=(value : Bool)
    service.set_refreshing(value)
  end

  def self.config_title=(value : String)
    service.set_config_title(value)
  end

  def self.clear : Nil
    service.clear
  end
end
