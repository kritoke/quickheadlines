require "spec"
require "../src/fetcher/semaphore_pool"

# Spec for RefreshLoop::SemaphorePool.
#
# Required directly here (not just transitively through spec_helper)
# so the constant is bound before the `describe` block runs.
#
# Each `it` block instantiates a fresh `SemaphorePool` to keep the
# tests independent — no `Spec.before_each` reset needed because the
# class is not a singleton here (the singleton lives in
# `RefreshLoop.pool` and is used by the supervisor at runtime, not
# in these unit tests).
describe RefreshLoop::SemaphorePool do
  describe "#initialize" do
    it "uses the default limit from QuickHeadlines::Constants::CONCURRENCY" do
      pool = RefreshLoop::SemaphorePool.new
      pool.limit.should eq(QuickHeadlines::Constants::CONCURRENCY)
    end

    it "accepts a custom limit" do
      pool = RefreshLoop::SemaphorePool.new(8)
      pool.limit.should eq(8)
    end

    it "starts at full capacity" do
      pool = RefreshLoop::SemaphorePool.new(3)
      pool.health_status[:available].should eq(3)
    end
  end

  describe "#acquire" do
    it "decrements the available count" do
      pool = RefreshLoop::SemaphorePool.new(4)
      pool.health_status[:available].should eq(4)
      pool.acquire
      pool.health_status[:available].should eq(3)
      pool.acquire
      pool.health_status[:available].should eq(2)
    end

    it "blocks when the pool is at capacity" do
      pool = RefreshLoop::SemaphorePool.new(1)
      pool.acquire # take the only slot

      # A second acquire in another fiber should not make progress
      # within a short window. If it did, the test would observe the
      # signaling channel.
      signal = Channel(Bool).new(1)
      spawn do
        pool.acquire
        signal.send(true)
      end

      select
      when signal.receive?
        fail "second acquire did not block at capacity"
      when timeout(0.1.seconds)
        # expected: the second fiber is still parked
      end
    end
  end

  describe "#release" do
    it "increments the available count" do
      pool = RefreshLoop::SemaphorePool.new(4)
      pool.acquire
      pool.acquire
      pool.health_status[:available].should eq(2)
      pool.release
      pool.health_status[:available].should eq(3)
    end

    it "allows a blocked acquirer to proceed" do
      pool = RefreshLoop::SemaphorePool.new(1)
      pool.acquire

      signal = Channel(Bool).new(1)
      spawn do
        pool.acquire
        signal.send(true)
      end

      # Give the spawned fiber a chance to park on the empty channel.
      sleep 0.01.seconds
      select
      when signal.receive?
        fail "second acquire should still be blocked before release"
      when timeout(0.05.seconds)
        # expected
      end

      pool.release

      # Now the parked acquirer should make progress.
      select
      when signal.receive?
        # expected
      when timeout(0.5.seconds)
        fail "blocked acquirer did not unblock after release"
      end
    end
  end

  describe "#health_status" do
    it "reports the expected limit" do
      pool = RefreshLoop::SemaphorePool.new(7)
      pool.health_status[:expected].should eq(7)
    end

    it "reports the current available count" do
      pool = RefreshLoop::SemaphorePool.new(5)
      3.times { pool.acquire }
      pool.health_status[:available].should eq(2)
    end
  end

  describe "#repair" do
    it "returns 0 when already at capacity" do
      pool = RefreshLoop::SemaphorePool.new(3)
      pool.repair.should eq(0)
    end

    it "refills missing slots and returns the count refilled" do
      pool = RefreshLoop::SemaphorePool.new(4)
      pool.acquire
      pool.acquire
      pool.health_status[:available].should eq(2)

      refilled = pool.repair
      refilled.should eq(2)
      pool.health_status[:available].should eq(4)
    end

    it "is safe to call concurrently from multiple fibers" do
      pool = RefreshLoop::SemaphorePool.new(4)
      pool.acquire
      pool.acquire
      pool.acquire # 1 available, 3 in use

      # Spawn several fibers that all call repair. They should
      # collectively refill the missing 3 slots, and the final
      # count should be exactly the limit (no double-refill).
      done = Channel(Nil).new(5)
      5.times do
        spawn do
          pool.repair
          done.send(nil)
        end
      end
      5.times { done.receive }

      pool.health_status[:available].should eq(4)
    end
  end

  describe "#reset_for_testing" do
    it "refills the pool to full capacity" do
      pool = RefreshLoop::SemaphorePool.new(4)
      pool.acquire
      pool.acquire
      pool.acquire
      pool.health_status[:available].should eq(1)

      pool.reset_for_testing
      pool.health_status[:available].should eq(4)
    end

    it "is a no-op when already at capacity" do
      pool = RefreshLoop::SemaphorePool.new(3)
      pool.reset_for_testing
      pool.health_status[:available].should eq(3)
    end

    it "can be used to unblock a parked acquirer" do
      pool = RefreshLoop::SemaphorePool.new(1)
      pool.acquire

      signal = Channel(Bool).new(1)
      spawn do
        pool.acquire
        signal.send(true)
      end

      sleep 0.01.seconds
      select
      when signal.receive?
        fail "second acquire should still be blocked before reset"
      when timeout(0.05.seconds)
        # expected
      end

      pool.reset_for_testing

      select
      when signal.receive?
        # expected
      when timeout(0.5.seconds)
        fail "blocked acquirer did not unblock after reset_for_testing"
      end
    end
  end
end
