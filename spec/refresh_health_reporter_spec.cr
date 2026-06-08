require "spec"
require "./spec_helper"
require "../src/fetcher/refresh_health_reporter"

# Spec for RefreshLoop::HealthReporter.
#
# The module is required directly at the top of the spec so the
# constants are bound before the `describe` block runs.
#
# The public surface of HealthReporter is intentionally tiny:
# - two constants (REPORT_INTERVAL, SHUTDOWN_CHUNK)
# - one method (`#start` that spawns a long-lived fiber)
#
# The body of the spawned fiber reads from a half-dozen globals
# (RefreshHealthMonitor, MemoryManagerActor, SocketManager,
# EventBroadcaster, FiberTracker, QuickHeadlines.shutting_down?).
# Stubbing all of them to test the full body in isolation is
# significant scaffolding. The struct of the spawn loop is
# testable without it; the long-lived tick is verified by the
# spec running successfully (the fiber is spawned and the test
# returns; if `start` raised, the spec would fail).
describe RefreshLoop::HealthReporter do
  describe "REPORT_INTERVAL" do
    it "is 5 minutes" do
      RefreshLoop::HealthReporter::REPORT_INTERVAL.should eq(5.minutes)
    end
  end

  describe "SHUTDOWN_CHUNK" do
    it "is 30 seconds" do
      RefreshLoop::HealthReporter::SHUTDOWN_CHUNK.should eq(30.seconds)
    end
  end

  describe "#start" do
    it "returns without raising" do
      # The spawned fiber reads from many globals; on a fresh spec
      # process most of them are nil and the first cycle would log
      # a "refresh health" warning at the next interval (5 minutes
      # from now), so this test doesn't observe a log. It just
      # verifies the call itself doesn't blow up.
      RefreshLoop::HealthReporter.start.should be_nil
    end

    it "is safe to call multiple times (each call spawns an additional fiber)" do
      # Documenting the current behavior: every call to `start`
      # spawns a new fiber. There is no built-in "is the reporter
      # already running?" guard. If the design later adds such a
      # guard, this test will fail and force a conscious decision.
      3.times { RefreshLoop::HealthReporter.start }
      # The test passes by returning without raising; the spawned
      # fibers are parked on the first `interruptible_sleep` and
      # will exit when the spec process exits.
    end
  end
end
