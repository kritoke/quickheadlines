require "athena"
require "../models"
require "./task_metadata"

# AppStateService manages the application state snapshot with thread-safe access.
# Wired by AppBootstrap at startup and injected into StateStore facade.
#
# This service replaces the class-level variables previously in StateStore module,
# following the black-box architecture principle of hiding implementation details
# behind clear interfaces.
module QuickHeadlines::Services
  class AppStateService
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
      @mutex.synchronize { @current = transform.call(@current) }
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

    def clustering=(value : Bool) : Nil
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

    def refreshing=(value : Bool) : Nil
      @refreshing.set(value)
      # Also sync to snapshot for backward-compatible API consumers
      update(&.copy_with(refreshing: value))
    end

    def config_title=(value : String) : Nil
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
