require "mutex"

# Tracks metadata for background tasks (clustering, admin actions).
# Thread-safe via its own mutex, independent of StateStore's main mutex.
module TaskMetadata
  extend self

  @@mutex = Mutex.new(:unchecked)

  # Cluster task tracking
  @@clustering_start_time : Time?
  @@last_cluster_run : Time?
  @@last_cluster_duration_ms : Int64 = 0_i64
  @@last_cluster_status : String = "idle"

  # Admin task tracking
  @@last_admin_action : String?
  @@last_admin_run : Time?
  @@last_admin_duration_ms : Int64 = 0_i64
  @@last_admin_status : String = "idle"

  def clustering_start_time : Time?
    @@mutex.synchronize { @@clustering_start_time }
  end

  def set_clustering_started : Nil
    @@mutex.synchronize { @@clustering_start_time = Time.utc }
  end

  def set_clustering_stopped : Nil
    @@mutex.synchronize { @@clustering_start_time = nil }
  end

  def last_cluster_run : Time?
    @@mutex.synchronize { @@last_cluster_run }
  end

  def last_cluster_duration_ms : Int64
    @@mutex.synchronize { @@last_cluster_duration_ms }
  end

  def last_cluster_status : String
    @@mutex.synchronize { @@last_cluster_status }
  end

  def set_cluster_completed(duration_ms : Int64, status : String) : Nil
    @@mutex.synchronize do
      @@last_cluster_run = Time.utc
      @@last_cluster_duration_ms = duration_ms
      @@last_cluster_status = status
    end
  end

  def last_admin_action : String?
    @@mutex.synchronize { @@last_admin_action }
  end

  def last_admin_run : Time?
    @@mutex.synchronize { @@last_admin_run }
  end

  def last_admin_duration_ms : Int64
    @@mutex.synchronize { @@last_admin_duration_ms }
  end

  def last_admin_status : String
    @@mutex.synchronize { @@last_admin_status }
  end

  def set_admin_completed(action : String, duration_ms : Int64, status : String) : Nil
    @@mutex.synchronize do
      @@last_admin_action = action
      @@last_admin_run = Time.utc
      @@last_admin_duration_ms = duration_ms
      @@last_admin_status = status
    end
  end
end
