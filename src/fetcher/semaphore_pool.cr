require "log"
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
# and reset. This class is the single owner of that state and exposes
# a narrow, testable API.
module RefreshLoop
  class SemaphorePool
    DEFAULT_LIMIT = QuickHeadlines::Constants::CONCURRENCY

    getter limit : Int32

    @channel : Channel(Nil)
    @counter : Atomic(Int32)
    @in_use : Atomic(Int32)
    @repair_mutex : Mutex

    def initialize(@limit : Int32 = DEFAULT_LIMIT)
      @channel = Channel(Nil).new(@limit)
      @limit.times { @channel.send(nil) }
      @counter = Atomic(Int32).new(@limit)
      @in_use = Atomic(Int32).new(0)
      @repair_mutex = Mutex.new(:unchecked)
    end

    def acquire : Nil
      @channel.receive
      @counter.sub(1)
      @in_use.add(1)
    end

    # Never blocks. If the channel is already full (e.g. a repair refilled a
    # slot that was in fact still held), the permit is dropped rather than
    # blocking the releasing fiber forever.
    def release : Nil
      @in_use.sub(1)
      select
      when @channel.send(nil)
        @counter.add(1)
      else
        Log.for("quickheadlines.feed").warn { "SemaphorePool#release: pool already full, dropping surplus permit" }
      end
    rescue Channel::ClosedError
    end

    def health_status : NamedTuple(available: Int32, expected: Int32)
      {available: @counter.get, expected: @limit}
    end

    # Refills only slots that are genuinely lost: neither available nor held
    # by a fiber that will release them. Slots held by slow or orphaned
    # fetches are NOT refilled, since their eventual release returns them.
    # Returns the number of slots refilled.
    def repair : Int32
      @repair_mutex.synchronize do
        lost = @limit - @counter.get - @in_use.get
        return 0 if lost <= 0
        refilled = 0
        lost.times do
          select
          when @channel.send(nil)
            @counter.add(1)
            refilled += 1
          else
            break
          end
        end
        refilled
      end
    end

    # Test-only: refill the pool to full capacity.
    def reset_for_testing : Nil
      @repair_mutex.synchronize do
        while @counter.get < @limit
          @counter.add(1)
          @in_use.set(0)
          @channel.send(nil)
        end
      end
    end
  end
end
