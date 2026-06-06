require "../config"
require "../models"
require "../software_fetcher"

module RefreshLoop
  private class State
    property active_config : Config
    property last_mtime : Time
    property cycle_count : Int32
    property consecutive_skips : Int32
    property initial_cancel_ch : Channel(Nil)?
    getter? first_run : Bool

    @first_run : Bool = true

    def initialize(@active_config : Config, @last_mtime : Time)
      @cycle_count = 0
      @consecutive_skips = 0
    end

    def mark_first_run_done : Nil
      @first_run = false
    end

    def heartbeat_due?(interval : Int32) : Bool
      @cycle_count > 0 && @cycle_count % interval == 0
    end

    def reset_cycle_count : Nil
      @cycle_count = 0
    end

    def increment_cycle : Nil
      @cycle_count += 1
    end

    def reset_skips : Nil
      @consecutive_skips = 0
    end

    def increment_skips : Int32
      @consecutive_skips += 1
      @consecutive_skips
    end

    def refresh_interval_seconds : Int32
      active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE
    end

    def outer_timeout_seconds : Int32
      refresh_interval_seconds * 3 // 2
    end

    def sleep_timeout_seconds : Int32
      refresh_interval_seconds * 3 // 2
    end

    def stuck_threshold_seconds : Int32
      refresh_interval_seconds * 3
    end

    def heartbeat_interval : Int32
      10
    end

    MAX_CONSECUTIVE_SKIPS = 3
  end
end
