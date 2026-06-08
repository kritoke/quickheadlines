require "spec"
require "./spec_helper"
require "../src/fetcher/interruptible_sleep"

# Spec for RefreshLoop::InterruptibleSleep.
#
# The helper has no state of its own and no globals it mutates
# (other than reading QuickHeadlines.shutting_down?), so each
# `it` block can call it directly. Some tests flip the
# shutting_down flag to interrupt a sleep; `Spec.after_each`
# resets it.
describe RefreshLoop::InterruptibleSleep do
  describe "DEFAULT_CHUNK" do
    it "is 30.seconds" do
      RefreshLoop::InterruptibleSleep::DEFAULT_CHUNK.should eq(30.seconds)
    end
  end

  describe ".sleep" do
    after_each do
      # Always reset the shutdown flag at the end of a test so
      # subsequent specs in the same process aren't affected.
      QuickHeadlines.shutting_down = false
    end

    it "returns immediately for a zero total" do
      start = Time.monotonic
      elapsed = RefreshLoop::InterruptibleSleep.sleep(Time::Span.zero)
      elapsed.should eq(Time::Span.zero)
      (Time.monotonic - start).should be < 0.1.seconds
    end

    it "sleeps for approximately the requested duration" do
      start = Time.monotonic
      elapsed = RefreshLoop::InterruptibleSleep.sleep(0.2.seconds)
      elapsed.should eq(0.2.seconds)
      (Time.monotonic - start).should be >= 0.15.seconds
      (Time.monotonic - start).should be < 0.5.seconds
    end

    it "returns early when QuickHeadlines.shutting_down? is true" do
      QuickHeadlines.shutting_down = true
      start = Time.monotonic
      elapsed = RefreshLoop::InterruptibleSleep.sleep(1.second)
      elapsed.should eq(Time::Span.zero)
      (Time.monotonic - start).should be < 0.1.seconds
    end

    it "respects outer_cap: exits when elapsed >= outer_cap even if total has not been reached" do
      # With outer_cap=0.05.seconds and total=1.second, the
      # helper should exit after the first chunk because
      # elapsed(>=0.05) >= outer_cap(0.05).
      start = Time.monotonic
      elapsed = RefreshLoop::InterruptibleSleep.sleep(1.second, outer_cap: 0.05.seconds, chunk: 0.1.seconds)
      elapsed.should be < 0.2.seconds
      (Time.monotonic - start).should be < 0.3.seconds
    end

    it "respects chunk: completes close to total for many small chunks" do
      # With a small chunk and no outer_cap, the loop should
      # complete close to the requested total.
      start = Time.monotonic
      elapsed = RefreshLoop::InterruptibleSleep.sleep(0.15.seconds, chunk: 0.05.seconds)
      elapsed.should eq(0.15.seconds)
      (Time.monotonic - start).should be >= 0.1.seconds
    end

    it "is interruptible mid-sleep: a fiber that signals shutdown returns before total elapses" do
      # Spawn a fiber that signals shutdown after a short delay,
      # then call .sleep. The helper should exit early.
      spawn do
        sleep 0.1.seconds
        QuickHeadlines.shutting_down = true
      end

      start = Time.monotonic
      elapsed = RefreshLoop::InterruptibleSleep.sleep(2.seconds, chunk: 0.05.seconds)
      (Time.monotonic - start).should be < 1.second
      elapsed.should be < 2.seconds
    end
  end
end
