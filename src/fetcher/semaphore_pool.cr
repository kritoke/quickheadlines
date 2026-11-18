require "../constants"

# Concurrency limit for per-feed fetcher fibers: a buffered channel
# pre-filled with `limit` permits. `release` runs in an `ensure`, so
# permits cannot leak and no repair step is needed.
module RefreshLoop
  class SemaphorePool
    DEFAULT_LIMIT = QuickHeadlines::Constants::CONCURRENCY

    getter limit : Int32

    def initialize(@limit : Int32 = DEFAULT_LIMIT)
      @channel = Channel(Nil).new(@limit)
      @limit.times { @channel.send(nil) }
    end

    def acquire : Nil
      @channel.receive
    end

    def release : Nil
      @channel.send(nil)
    end
  end
end
