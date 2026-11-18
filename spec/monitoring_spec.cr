require "spec"
require "../src/fetcher/monitoring"

describe RefreshLoop::Monitoring do
  before_each do
    # Reset state before each test
    RefreshLoop::Monitoring.reset_failures
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
end
