require "spec"
require "./spec_helper"
require "../src/services/fiber_tracker"

# Spec for RefreshLoop::FiberTracker.
describe RefreshLoop::FiberTracker do
  # Reset the module-level counters between tests.
  Spec.before_each do
    RefreshLoop::FiberTracker.reset
  end

  describe ".track_spawn" do
    it "increments @@fiber_spawns by 1" do
      before = spawn_count
      RefreshLoop::FiberTracker.track_spawn
      spawn_count.should eq(before + 1)
    end

    it "increments @@active_fibers by 1" do
      before = active_count
      RefreshLoop::FiberTracker.track_spawn
      active_count.should eq(before + 1)
    end

    it "updates @@peak_fibers to the highest active count seen" do
      RefreshLoop::FiberTracker.track_spawn # active=1, peak=1
      RefreshLoop::FiberTracker.track_spawn # active=2, peak=2
      RefreshLoop::FiberTracker.track_spawn # active=3, peak=3
      peak_count.should eq(3)
    end
  end

  describe ".track_exit" do
    it "decrements @@active_fibers by 1" do
      RefreshLoop::FiberTracker.track_spawn
      before = active_count
      RefreshLoop::FiberTracker.track_exit
      active_count.should eq(before - 1)
    end

    it "does not go below 0 (clamped at 0)" do
      # Even if track_exit is called without a matching track_spawn,
      # the active count must not underflow.
      3.times { RefreshLoop::FiberTracker.track_exit }
      active_count.should eq(0)
    end
  end

  describe ".tracked_spawn" do
    it "spawns the fiber and tracks spawn/exit" do
      active_before = active_count

      done = Channel(Int32).new(1)
      RefreshLoop::FiberTracker.tracked_spawn do
        # Inside the fiber, the active count is what was counted
        # AT spawn time. The block has just started, so the fiber
        # has not yet exited.
        done.send(active_count)
      end

      active_inside_fiber = done.receive
      active_inside_fiber.should eq(active_before + 1)

      # Give the fiber time to exit, then check the active count
      # went back to baseline.
      sleep 0.05.seconds
      active_count.should eq(active_before)
      spawn_count.should eq(1)
    end

    it "tracks spawn/exit even if the fiber body raises" do
      # The `ensure` block in `tracked_spawn` guarantees `track_exit`
      # runs even if the block raises. This is the regression guard
      # for the counter-leak that would happen if track_exit were
      # only in the success path.
      #
      # Note: `expect_raises(Exception)` doesn't work here because
      # the spawn is async — the exception fires in the spawned
      # fiber, not in the test's main fiber. We assert the counter
      # behavior instead: after the raise, the ensure block runs
      # and decrements @@active_fibers back to baseline.
      active_before = active_count

      # The fiber raises in a separate fiber; we just need to wait
      # long enough for the raise to propagate and the ensure
      # block to run. Use a Channel to signal completion.
      done = Channel(Nil).new(1)
      spawn do
        begin
          RefreshLoop::FiberTracker.tracked_spawn do
            raise "boom"
          end
        rescue
          # Swallow the raise so the watching fiber doesn't die too.
        end
        done.send(nil)
      end
      done.receive
      # Give the spawned fiber a beat to finish.
      Fiber.yield
      Fiber.yield

      active_count.should eq(active_before)
    end

    it "accepts an optional fiber name" do
      # The name is just passed through to `spawn(name: ...)`. We
      # don't assert anything observable from the name (Crystal 1.18
      # doesn't expose a fiber list), but the call should not raise
      # and the counters should still be updated.
      done = Channel(Int32).new(1)
      RefreshLoop::FiberTracker.tracked_spawn("test_fiber") do
        done.send(1)
      end
      done.receive
      sleep 0.05.seconds
      spawn_count.should eq(1)
    end
  end

  describe ".stats" do
    it "returns a string containing all three counters" do
      RefreshLoop::FiberTracker.track_spawn
      stats = RefreshLoop::FiberTracker.stats
      stats.should contain "active=1"
      stats.should contain "spawns=1"
      stats.should contain "peak=1"
    end
  end
end

# Top-level helpers — Crystal does not allow `def` inside a
# `describe` block. We parse the public `stats` string to read
# the counters, keeping the spec decoupled from the underlying
# atomics.
def parse_stats(key : String) : Int32
  stats = RefreshLoop::FiberTracker.stats
  # The stats string is "active=N, peak=N, spawns=N". Match the key
  # followed by `=` anywhere in the string (not just at the start).
  if match = stats.match(/#{key}=(\d+)/)
    match[1].to_i
  else
    raise "could not parse #{key} from #{stats.inspect}"
  end
end

def active_count : Int32
  parse_stats("active")
end

def spawn_count : Int32
  parse_stats("spawns")
end

def peak_count : Int32
  parse_stats("peak")
end
