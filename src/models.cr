require "mutex"

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

# Thread-safe state store with atomic updates
module StateStore
  @@current = AppStateSnapshot.new(
    feeds: [] of FeedData,
    tabs: [] of Tab,
    updated_at: Time.utc,
    config_title: "Quick Headlines",
    config: nil,
    clustering: false,
    refreshing: false
  )
  # NOTE: Uses :unchecked mutex to avoid Boehm GC mutex initialization
  # deadlocks on FreeBSD. See AGENTS.md for details.
  @@mutex = Mutex.new(:unchecked)
  # Separate mutex for admin/cluster metadata to reduce contention on hot-path get/update
  @@metadata_mutex = Mutex.new(:unchecked)
  @@clustering_start_time : Time?

  # Fast-path atomics for frequently-read boolean flags.
  # These avoid mutex acquisition for the hot read path (API status checks).
  # Writers use atomic set, so readers get a consistent value without locking.
  @@refreshing = Atomic(Bool).new(false)
  @@clustering = Atomic(Bool).new(false)

  # Background task tracking — protected by @@metadata_mutex only
  @@last_cluster_run : Time?
  @@last_cluster_duration_ms : Int64 = 0_i64
  @@last_cluster_status : String = "idle"
  @@last_admin_action : String?
  @@last_admin_run : Time?
  @@last_admin_duration_ms : Int64 = 0_i64
  @@last_admin_status : String = "idle"

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
    @@clustering.get
  end

  def self.clustering=(value : Bool)
    @@clustering.set(value)
    if value
      @@metadata_mutex.synchronize { @@clustering_start_time = Time.utc }
    else
      @@metadata_mutex.synchronize { @@clustering_start_time = nil }
    end
    # Also sync to snapshot for backward-compatible API consumers
    update(&.copy_with(clustering: value))
  end

  def self.start_clustering_if_idle : Bool
    # Use CAS to atomically check-and-set without holding @@mutex for the check.
    # This prevents contention when many fibers are checking clustering status.
    expected = false
    if @@clustering.compare_and_set(expected, true)
      @@metadata_mutex.synchronize { @@clustering_start_time = Time.utc }
      update(&.copy_with(clustering: true))
      true
    else
      false
    end
  end

  def self.clustering_start_time : Time?
    @@metadata_mutex.synchronize { @@clustering_start_time }
  end

  def self.last_cluster_run : Time?
    @@metadata_mutex.synchronize { @@last_cluster_run }
  end

  def self.last_cluster_duration_ms : Int64
    @@metadata_mutex.synchronize { @@last_cluster_duration_ms }
  end

  def self.last_cluster_status : String
    @@metadata_mutex.synchronize { @@last_cluster_status }
  end

  def self.set_cluster_completed(duration_ms : Int64, status : String) : Nil
    @@metadata_mutex.synchronize do
      @@last_cluster_run = Time.utc
      @@last_cluster_duration_ms = duration_ms
      @@last_cluster_status = status
    end
  end

  def self.last_admin_action : String?
    @@metadata_mutex.synchronize { @@last_admin_action }
  end

  def self.last_admin_run : Time?
    @@metadata_mutex.synchronize { @@last_admin_run }
  end

  def self.last_admin_duration_ms : Int64
    @@metadata_mutex.synchronize { @@last_admin_duration_ms }
  end

  def self.last_admin_status : String
    @@metadata_mutex.synchronize { @@last_admin_status }
  end

  def self.set_admin_completed(action : String, duration_ms : Int64, status : String) : Nil
    @@metadata_mutex.synchronize do
      @@last_admin_action = action
      @@last_admin_run = Time.utc
      @@last_admin_duration_ms = duration_ms
      @@last_admin_status = status
    end
  end

  def self.refreshing?
    @@refreshing.get
  end

  def self.refreshing=(value : Bool)
    @@refreshing.set(value)
    # Also sync to snapshot for backward-compatible API consumers
    update(&.copy_with(refreshing: value))
  end

  def self.config_title=(value : String)
    update(&.copy_with(config_title: value))
  end

  def self.clear : Nil
    @@mutex.synchronize do
      @@refreshing.set(false)
      @@clustering.set(false)
      @@current = AppStateSnapshot.new(
        feeds: [] of FeedData,
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
