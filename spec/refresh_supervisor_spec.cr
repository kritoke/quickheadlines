require "spec"
require "./spec_helper"
require "../src/fetcher/refresh_supervisor"

# Spec for RefreshLoop::Supervisor.
#
# Covers the parts of the class that don't require mocking the
# supervisor's many global dependencies (StateStore, RefreshHealthMonitor,
# MemoryManagerActor, etc.):
# - the class-level constants
# - the nested `State` class (now public on the module)
# - the early-return path of `#start` when the config file fails
#   to load
#
# What is NOT covered (documented in the spec):
# - The long-lived spawn loop and helper methods
#   (`run_one_iteration`, `check_stuck_recovery`,
#   `reload_config_if_changed`, etc.) are tightly coupled to
#   globals. Unit-testing the full body requires substantial
#   mocks; defer until a real bug surfaces.
# - The private `interruptible_sleep` instance method is not
#   exercised directly. The chunked-sleep primitive now lives in
#   RefreshLoop::InterruptibleSleep and has its own spec.
describe RefreshLoop::Supervisor do
  describe "class constants" do
    it "RESTART_DELAY_AFTER_ERROR is 60.seconds" do
      RefreshLoop::Supervisor::RESTART_DELAY_AFTER_ERROR.should eq(60.seconds)
    end

    it "HEARTBEAT_INTERVAL is 10" do
      RefreshLoop::Supervisor::HEARTBEAT_INTERVAL.should eq(10)
    end

    it "LONG_REFRESH_DURATION_WARN is 120.seconds" do
      RefreshLoop::Supervisor::LONG_REFRESH_DURATION_WARN.should eq(120.seconds)
    end
  end

  describe "State" do
    describe "constructor" do
      it "initializes cycle_count and consecutive_skips to 0" do
        config = build_supervisor_config
        now = Time.utc
        state = RefreshLoop::Supervisor::State.new(config, now)

        state.cycle_count.should eq(0)
        state.consecutive_skips.should eq(0)
      end

      it "stores active_config and last_mtime" do
        config = build_supervisor_config
        now = Time.utc
        state = RefreshLoop::Supervisor::State.new(config, now)

        state.active_config.should eq(config)
        state.last_mtime.should eq(now)
      end

      it "is first_run by default" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        state.first_run?.should be_true
      end
    end

    describe "mark_first_run_done" do
      it "clears first_run" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        state.first_run?.should be_true
        state.mark_first_run_done
        state.first_run?.should be_false
      end
    end

    describe "heartbeat_due?" do
      it "returns false when cycle_count is 0 (the supervisor has not completed any cycles yet)" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        state.heartbeat_due?(10).should be_false
      end

      it "returns true when cycle_count is exactly a multiple of interval" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        state.cycle_count = 10
        state.heartbeat_due?(10).should be_true
      end

      it "returns false when cycle_count is not a multiple of interval" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        state.cycle_count = 11
        state.heartbeat_due?(10).should be_false
      end
    end

    describe "cycle_count mutations" do
      it "increment_cycle and reset_cycle_count" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        state.increment_cycle
        state.increment_cycle
        state.cycle_count.should eq(2)
        state.reset_cycle_count
        state.cycle_count.should eq(0)
      end
    end

    describe "consecutive_skips mutations" do
      it "increment_skips returns the new value" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        state.increment_skips.should eq(1)
        state.increment_skips.should eq(2)
        state.increment_skips.should eq(3)
      end

      it "reset_skips brings the count back to 0" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config, Time.utc)
        3.times { state.increment_skips }
        state.reset_skips
        state.consecutive_skips.should eq(0)
      end

      it "MAX_CONSECUTIVE_SKIPS is 3" do
        # The supervisor force-resets the refreshing flag after
        # this many consecutive skips to recover from a stuck
        # refresh. Verify the value is the expected constant.
        RefreshLoop::Supervisor::State::MAX_CONSECUTIVE_SKIPS.should eq(3)
      end
    end

    describe "derived timing values" do
      it "refresh_interval_seconds is refresh_minutes * 60" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config(refresh_minutes: 30), Time.utc)
        state.refresh_interval_seconds.should eq(30 * 60)
      end

      it "outer_timeout_seconds is refresh_interval * OUTER_TIMEOUT_SECONDS / 2" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config(refresh_minutes: 30), Time.utc)
        # OUTER_TIMEOUT_SECONDS = 3 (from QuickHeadlines::Constants)
        # refresh_interval = 30 * 60 = 1800
        # outer_timeout = 1800 * 3 // 2 = 2700
        state.outer_timeout_seconds.should eq(30 * 60 * 3 // 2)
      end

      it "sleep_timeout_seconds is refresh_interval * SLEEP_TIMEOUT_SECONDS / 2" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config(refresh_minutes: 30), Time.utc)
        # SLEEP_TIMEOUT_SECONDS = 3
        state.sleep_timeout_seconds.should eq(30 * 60 * 3 // 2)
      end

      it "stuck_threshold_seconds is refresh_interval * STUCK_THRESHOLD_SECONDS" do
        state = RefreshLoop::Supervisor::State.new(build_supervisor_config(refresh_minutes: 30), Time.utc)
        # STUCK_THRESHOLD_SECONDS = 3
        state.stuck_threshold_seconds.should eq(30 * 60 * 3)
      end
    end
  end

  describe ".start" do
    it "returns early (no exception) when the config path does not exist" do
      semaphore = RefreshLoop::SemaphorePool.new
      # Build our own Config and DatabaseService so we don't depend
      # on the DatabaseService singleton being initialized.
      config = build_supervisor_config
      db_service = DatabaseService.new(config)
      cache = FeedCache.new(config, db_service)

      # The path is intentionally invalid; the supervisor's
      # `load_validated_config` returns a failure result, the
      # supervisor logs and returns, and the test passes without
      # any fibers being spawned.
      result = RefreshLoop::Supervisor.start("/nonexistent/path/feeds.yml", cache, db_service, semaphore)
      result.should be_nil
    end
  end
end

# Helper to build a minimal Config for State tests.
def build_supervisor_config(refresh_minutes : Int32 = 30) : Config
  yaml = <<-YAML
    cache_dir: #{Dir.tempdir}
    db_path: #{File.join(Dir.tempdir, "qh_test_sup_#{Process.pid}_#{Random.rand(10000)}.db")}
    refresh_minutes: #{refresh_minutes}
    item_limit: 5
    feeds: []
    tabs: []
    YAML
  Config.from_yaml(yaml)
end
