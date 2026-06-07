require "../constants"

# Per-process concurrency semaphore for the feed refresh loop.
#
# The pool has a configurable limit (default
# `QuickHeadlines::Constants::CONCURRENCY = 4`) and tracks an atomic
# counter so health checks can read availability without draining the
# channel.
#
# Exposes:
# - `#acquire` / `#release`   — taken by per-feed fetcher fibers
# - `#health_status`          — zero-side-effect inspection
# - `#repair`                 — refill missing slots under a mutex (supervisor)
# - `#reset_for_testing`      — bring the pool back to full capacity (tests only)
#
# The previous design used module-level `@@` state lazily initialized
# under a Mutex inside `RefreshLoop`. That made the state hard to test
# and reset, and forced the rest of the codebase to reach into the
# module to call `acquire_semaphore` / `release_semaphore`. This class
# is the single owner of that state and exposes a narrow, testable API.
module RefreshLoop
  class SemaphorePool
    DEFAULT_LIMIT = QuickHeadlines::Constants::CONCURRENCY

    getter limit : Int32

    @channel : Channel(Nil)
    @counter : Atomic(Int32)
    @repair_mutex : Mutex

    def initialize(@limit : Int32 = DEFAULT_LIMIT)
      @channel = Channel(Nil).new(@limit)
      @limit.times { @channel.send(nil) }
      @counter = Atomic(Int32).new(@limit)
      @repair_mutex = Mutex.new(:unchecked)
    end

    def acquire : Nil
      @channel.receive
      @counter.add(-1, :relaxed)
    end

    def release : Nil
      @counter.add(1, :relaxed)
      @channel.send(nil)
    rescue Channel::ClosedError
    end

    def health_status : NamedTuple(available: Int32, expected: Int32)
      {available: @counter.get, expected: @limit}
    end

    # Returns the number of slots that were refilled (0 if already at
    # capacity). Safe to call from multiple fibers; the underlying
    # `@repair_mutex` serializes refills.
    def repair : Int32
      @repair_mutex.synchronize do
        available = @counter.get
        return 0 if available == @limit
        missing = @limit - available
        missing.times do
          @channel.send(nil)
          @counter.add(1)
        end
        missing
      end
    end

    # Test-only: refill the pool to full capacity.
    def reset_for_testing : Nil
      @repair_mutex.synchronize do
        while @counter.get < @limit
          @counter.add(1, :relaxed)
          @channel.send(nil)
        end
      end
    end
  end
end
