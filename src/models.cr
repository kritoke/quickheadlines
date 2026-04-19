require "mutex"

record Item, title : String, link : String, pub_date : Time?, version : String? = nil, comment_url : String? = nil, commentary_url : String? = nil

record ClusteringItemRow,
  id : Int64,
  title : String,
  link : String,
  pub_date : Time?,
  feed_url : String,
  feed_title : String,
  favicon : String?,
  favicon_data : String?,
  header_color : String?

record FeedData,
  title : String, url : String, site_link : String,
  header_color : String?, header_text_color : String?,
  items : Array(Item), etag : String? = nil, last_modified : String? = nil,
  favicon : String? = nil, favicon_data : String? = nil,
  error_message : String? = nil, header_theme_colors : String? = nil do
  def display_header_color
    (header_color.try(&.strip).presence) || "transparent"
  end

  def display_header_text_color
    header_text_color.try(&.strip).presence
  end

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
  software_releases : Array(FeedData),
  tabs : Array(Tab),
  updated_at : Time,
  config_title : String,
  config : Config?,
  clustering : Bool,
  refreshing : Bool

# Thread-safe state store with atomic updates
module StateStore
  @@current = AppStateSnapshot.new(
    feeds: [] of FeedData,
    software_releases: [] of FeedData,
    tabs: [] of Tab,
    updated_at: Time.utc,
    config_title: "Quick Headlines",
    config: nil,
    clustering: false,
    refreshing: false
  )
  @@mutex = Mutex.new
  @@clustering_start_time : Time?

  def self.get : AppStateSnapshot
    @@mutex.synchronize { @@current }
  end

  def self.update(&transform : AppStateSnapshot -> AppStateSnapshot) : AppStateSnapshot
    @@mutex.synchronize do
      @@current = transform.call(@@current)
      @@current
    end
  end

  def self.feeds
    get.feeds
  end

  def self.tabs
    get.tabs
  end

  def self.software_releases
    get.software_releases
  end

  def self.updated_at
    get.updated_at
  end

  def self.config
    get.config
  end

  def self.config_title
    get.config_title
  end

  def self.clustering?
    get.clustering
  end

  def self.clustering=(value : Bool)
    @@mutex.synchronize do
      @@current = @@current.copy_with(clustering: value)
      unless value
        @@clustering_start_time = nil
      end
    end
  end

  def self.start_clustering_if_idle : Bool
    @@mutex.synchronize do
      if @@current.clustering
        return false
      end
      @@current = @@current.copy_with(clustering: true)
      @@clustering_start_time = Time.utc
      true
    end
  end

  def self.clustering_start_time : Time?
    @@clustering_start_time
  end

  def self.refreshing?
    get.refreshing
  end

  def self.refreshing=(value : Bool)
    update(&.copy_with(refreshing: value))
  end

  def self.config_title=(value : String)
    update(&.copy_with(config_title: value))
  end

  def self.clear : Nil
    @@mutex.synchronize do
      @@current = AppStateSnapshot.new(
        feeds: [] of FeedData,
        software_releases: [] of FeedData,
        tabs: [] of Tab,
        updated_at: Time.utc,
        config_title: "Quick Headlines",
        config: nil,
        clustering: false,
        refreshing: false
      )
    end
  end
end
