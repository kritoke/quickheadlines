require "time"
require "log"
require "./constants"

module QuickHeadlines
  # Sliding-window rate limiter, in-process and Mutex-guarded.
  #
  # Each (key, max_requests, window_seconds) combination has its own window of
  # request timestamps. Counting is exact: a request is allowed only while the
  # window holds fewer than `max_requests` entries, so the limit can never be
  # exceeded. Idle entries are evicted after RATE_LIMITER_INSTANCE_TTL seconds
  # (checked at most every RATE_LIMITER_CLEANUP_INTERVAL seconds), which keeps
  # memory bounded to recently active clients.
  class RateLimiter
    private class Window
      getter last_accessed : Int64

      def initialize(@max_requests : Int32, @window_seconds : Int32)
        @requests = Deque(Int64).new
        @last_accessed = Time.utc.to_unix
      end

      def allow?(now : Int64) : Bool
        prune(now)
        @last_accessed = now
        return false if @requests.size >= @max_requests
        @requests << now
        true
      end

      def retry_after(now : Int64) : Int32
        prune(now)
        oldest = @requests.first?
        return @window_seconds unless oldest
        (@window_seconds - (now - oldest)).to_i32.clamp(1, @window_seconds)
      end

      private def prune(now : Int64) : Nil
        cutoff = now - @window_seconds
        while (first = @requests.first?) && first < cutoff
          @requests.shift
        end
      end
    end

    @@mutex = Mutex.new
    @@windows = {} of String => Window
    @@last_cleanup = Time.utc.to_unix

    def self.allowed?(key : String, max_requests : Int32 = 60, window_seconds : Int32 = 60) : Bool
      now = Time.utc.to_unix
      @@mutex.synchronize do
        maybe_cleanup(now)
        window = (@@windows["#{key}:#{max_requests}:#{window_seconds}"] ||= Window.new(max_requests, window_seconds))
        window.allow?(now)
      end
    end

    # Seconds until the oldest request for `key` (any max_requests) leaves the
    # window; `window_seconds` when the key has no recorded requests.
    def self.retry_after(key : String, window_seconds : Int32 = 60) : Int32
      now = Time.utc.to_unix
      prefix = "#{key}:"
      suffix = ":#{window_seconds}"
      @@mutex.synchronize do
        retries = @@windows.compact_map do |limiter_key, window|
          window.retry_after(now) if limiter_key.starts_with?(prefix) && limiter_key.ends_with?(suffix)
        end
        retries.min? || window_seconds
      end
    end

    def self.shutdown : Nil
      clear_cache
    end

    # Number of tracked limiter windows (reported in the health log).
    def self.cache_size : Int32
      @@mutex.synchronize { @@windows.size }
    end

    def self.clear_cache : Nil
      @@mutex.synchronize { @@windows.clear }
    end

    private def self.maybe_cleanup(now : Int64) : Nil
      return if now - @@last_cleanup < Constants::RATE_LIMITER_CLEANUP_INTERVAL
      @@last_cleanup = now
      cutoff = now - Constants::RATE_LIMITER_INSTANCE_TTL
      before = @@windows.size
      @@windows.reject! { |_, window| window.last_accessed < cutoff }
      removed = before - @@windows.size
      Log.for("quickheadlines.ratelimiter").debug { "Evicted #{removed} idle rate limiter windows" } if removed > 0
    end
  end
end
