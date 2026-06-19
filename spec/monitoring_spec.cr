require "spec"
require "../src/fetcher/monitoring"

describe RefreshLoop::Monitoring do
  before_each do
    # Reset state before each test
    RefreshLoop::Monitoring.reset_failures
    RefreshLoop::Monitoring.last_refresh_start_for_testing = 0_i64
    RefreshLoop::Monitoring.last_refresh_complete_for_testing = 0_i64
  end

  describe "constants" do
    it "has REPORT_INTERVAL of 5 minutes" do
      RefreshLoop::Monitoring::REPORT_INTERVAL.should eq(5.minutes)
    end
  end

  describe "state tracking" do
    it "record_cycle_start sets last_refresh_start" do
      before = Time.utc.to_unix_ms
      RefreshLoop::Monitoring.record_cycle_start
      status = RefreshLoop::Monitoring.status
      status[:last_start].should be >= before
    end

    it "record_cycle_complete sets last_refresh_complete and increments cycles" do
      before_cycles = RefreshLoop::Monitoring.status[:cycles]
      RefreshLoop::Monitoring.record_cycle_complete
      status = RefreshLoop::Monitoring.status
      status[:cycles].should eq(before_cycles + 1)
      status[:last_complete].should be > 0
    end

    it "record_failure increments failures" do
      before_failures = RefreshLoop::Monitoring.status[:failures]
      RefreshLoop::Monitoring.record_failure
      RefreshLoop::Monitoring.status[:failures].should eq(before_failures + 1)
    end

    it "reset_failures zeroes failures" do
      RefreshLoop::Monitoring.record_failure
      RefreshLoop::Monitoring.record_failure
      RefreshLoop::Monitoring.reset_failures
      RefreshLoop::Monitoring.status[:failures].should eq(0)
    end

    it "feed_fetch_started increments feeds_in_progress" do
      before = RefreshLoop::Monitoring.status[:feeds_in_progress]
      RefreshLoop::Monitoring.feed_fetch_started
      RefreshLoop::Monitoring.status[:feeds_in_progress].should eq(before + 1)
    end

    it "feed_fetch_completed decrements feeds_in_progress" do
      RefreshLoop::Monitoring.feed_fetch_started
      RefreshLoop::Monitoring.feed_fetch_started
      before = RefreshLoop::Monitoring.status[:feeds_in_progress]
      RefreshLoop::Monitoring.feed_fetch_completed
      RefreshLoop::Monitoring.status[:feeds_in_progress].should eq(before - 1)
    end

    it "feed_fetch_completed clamps at 0" do
      # Reset to 0
      while RefreshLoop::Monitoring.status[:feeds_in_progress] > 0
        RefreshLoop::Monitoring.feed_fetch_completed
      end
      # Should not go negative
      RefreshLoop::Monitoring.feed_fetch_completed
      RefreshLoop::Monitoring.status[:feeds_in_progress].should eq(0)
    end
  end

  describe "status" do
    it "returns expected shape" do
      status = RefreshLoop::Monitoring.status
      status.has_key?(:last_start).should be_true
      status.has_key?(:last_complete).should be_true
      status.has_key?(:cycles).should be_true
      status.has_key?(:failures).should be_true
      status.has_key?(:feeds_in_progress).should be_true
    end
  end

  describe "stuck?" do
    it "returns false when never started" do
      RefreshLoop::Monitoring.stuck?(60).should be_false
    end

    it "returns false when last_complete > start_time" do
      RefreshLoop::Monitoring.record_cycle_start
      RefreshLoop::Monitoring.record_cycle_complete
      RefreshLoop::Monitoring.stuck?(60).should be_false
    end

    it "returns true when age exceeds max_age_seconds" do
      # Set start time to 120 seconds ago
      old_time = (Time.utc - 120.seconds).to_unix_ms
      RefreshLoop::Monitoring.last_refresh_start_for_testing = old_time
      RefreshLoop::Monitoring.stuck?(60).should be_true
    end

    it "returns false when age is within max_age_seconds" do
      RefreshLoop::Monitoring.record_cycle_start
      RefreshLoop::Monitoring.stuck?(120).should be_false
    end
  end

  describe "attempt_recovery" do
    it "returns true and zeros start time when stuck" do
      old_time = (Time.utc - 120.seconds).to_unix_ms
      RefreshLoop::Monitoring.last_refresh_start_for_testing = old_time
      result = RefreshLoop::Monitoring.attempt_recovery
      result.should be_true
      RefreshLoop::Monitoring.status[:last_start].should eq(0)
    end

    it "returns false when not stuck" do
      now = Time.utc.to_unix_ms
      RefreshLoop::Monitoring.last_refresh_start_for_testing = now
      RefreshLoop::Monitoring.last_refresh_complete_for_testing = now + 1000
      RefreshLoop::Monitoring.attempt_recovery.should be_false
    end

    it "returns false when never started" do
      RefreshLoop::Monitoring.attempt_recovery.should be_false
    end
  end

  describe "testing setters" do
    it "last_refresh_start_for_testing= sets the value" do
      RefreshLoop::Monitoring.last_refresh_start_for_testing = 12345_i64
      RefreshLoop::Monitoring.status[:last_start].should eq(12345_i64)
    end

    it "last_refresh_complete_for_testing= sets the value" do
      RefreshLoop::Monitoring.last_refresh_complete_for_testing = 67890_i64
      RefreshLoop::Monitoring.status[:last_complete].should eq(67890_i64)
    end
  end
end
