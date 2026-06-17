require "athena"
require "../models"
require "./task_metadata"
require "./memory_manager_actor"

# AppStateService manages the application state snapshot with thread-safe access.
# Wired by AppBootstrap at startup and injected into StateStore facade.
#
# This service replaces the class-level variables previously in StateStore module,
# following the black-box architecture principle of hiding implementation details
# behind clear interfaces.
module QuickHeadlines::Services
  class AppStateService
    # Memory history tracking for leak diagnosis
    # Format: Array of {timestamp, rss_mb, state_snapshot_size}
    @memory_history = [] of {time: Time, rss_mb: Float64, feeds_count: Int32, items_count: Int32}
    @memory_history_max_entries = 500 # ~4 hours at 30s intervals

    @current = AppStateSnapshot.new(
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
    @mutex = Mutex.new(:unchecked)

    # Fast-path atomics for frequently-read boolean flags.
    # These avoid mutex acquisition for the hot read path (API status checks).
    # Writers use atomic set, so readers get a consistent value without locking.
    @refreshing = Atomic(Bool).new(false)
    @clustering = Atomic(Bool).new(false)

    def get : AppStateSnapshot
      @mutex.synchronize { @current }
    end

    def update(&transform : AppStateSnapshot -> AppStateSnapshot) : AppStateSnapshot
      Log.for("quickheadlines.state").debug { "update" }
      @mutex.synchronize do
        @current = transform.call(@current)

        # Track memory growth after state updates
        track_memory_usage

        @current
      end
    end

    # Track memory usage for leak diagnosis
    private def track_memory_usage : Nil
      # Only track every 10 updates to reduce overhead
      return if @memory_history.size % 10 != 0

      begin
        rss_mb = MemoryManagerActor.instance.get_memory_status.rss_mb
        feeds_count = @current.feeds.size
        items_count = @current.feeds.sum(&.items.size)

        @memory_history << {time: Time.utc, rss_mb: rss_mb, feeds_count: feeds_count, items_count: items_count}
        @memory_history.shift if @memory_history.size > @memory_history_max_entries
      rescue ex : Exception
        Log.for("quickheadlines.memory").debug { "Memory tracking error: #{ex.message}" }
      end
    end

    def memory_history_summary : String
      return "No history" if @memory_history.empty?
      recent = @memory_history.last(20)
      rss_values = recent.map(&.[:rss_mb])
      "min_rss=#{rss_values.min.round(1)}MB, max_rss=#{rss_values.max.round(1)}MB, current=#{rss_values.last.round(1)}MB, samples=#{recent.size}"
    end

    def memory_growth_rate : String
      return "No history" if @memory_history.size < 10
      recent = @memory_history.last(10)
      time_span_hrs = (recent.last[:time] - recent.first[:time]).total_hours
      return "No history" if time_span_hrs < 0.01

      rss_diff = recent.last[:rss_mb] - recent.first[:rss_mb]
      rate = rss_diff / time_span_hrs
      "#{rate.round(2)}MB/hr (#{rss_diff.round(1)}MB over #{time_span_hrs.round(1)}hrs)"
    end

    def feeds : Array(FeedData)
      get.feeds
    end

    def tabs : Array(Tab)
      get.tabs
    end

    def updated_at : Time
      get.updated_at
    end

    def config : Config?
      get.config
    end

    def config_title : String
      get.config_title
    end

    def clustering? : Bool
      @clustering.get
    end

    def set_clustering(value : Bool) : Nil
      @clustering.set(value)
      if value
        TaskMetadata.set_clustering_started
      else
        TaskMetadata.set_clustering_stopped
      end
      # Also sync to snapshot for backward-compatible API consumers
      update(&.copy_with(clustering: value))
    end

    def start_clustering_if_idle : Bool
      # Use CAS to atomically check-and-set without holding @mutex for the check.
      # This prevents contention when many fibers are checking clustering status.
      expected = false
      if @clustering.compare_and_set(expected, true)
        TaskMetadata.set_clustering_started
        update(&.copy_with(clustering: true))
        true
      else
        false
      end
    end

    def refreshing? : Bool
      @refreshing.get
    end

    def set_refreshing(value : Bool) : Nil
      @refreshing.set(value)
      # Also sync to snapshot for backward-compatible API consumers
      update(&.copy_with(refreshing: value))
    end

    def set_config_title(value : String) : Nil
      update(&.copy_with(config_title: value))
    end

    def clear : Nil
      @mutex.synchronize do
        @refreshing.set(false)
        @clustering.set(false)
        @current = AppStateSnapshot.new(
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
end
