require "time"
require "./infrastructure/actor"
require "./constants"

# ThrottlerActor — rate limiting with actor-based serialization.
#
# All rate limit state is owned by a single actor fiber. No mutexes needed.
# Cleanup runs on a timer inside the actor loop.
#
module QuickHeadlines
  class ThrottlerActor < Actor
    # =========================================================================
    # Per-key rate limiter state (plain data, no mutex needed)
    # =========================================================================

    class LimiterState
      property requests : Array(Int64)
      property last_accessed : Int64

      def initialize(@max_requests : Int32, @window_seconds : Int32)
        @requests = [] of Int64
        @last_accessed = Time.utc.to_unix
      end

      def allowed?(now : Int64) : Bool
        cutoff = now - @window_seconds
        @requests.reject! { |t| t < cutoff }

        if @requests.size >= @max_requests
          false
        else
          @requests << now
          @last_accessed = now
          true
        end
      end

      def retry_after(now : Int64) : Int32
        return @window_seconds if @requests.empty?

        cutoff = now - @window_seconds
        @requests.reject! { |t| t < cutoff }
        return @window_seconds if @requests.empty?

        oldest = @requests.min
        elapsed = now - oldest
        retry_seconds = @window_seconds - elapsed
        retry_seconds < 1 ? 1 : retry_seconds
      end
    end

    # =========================================================================
    # Messages
    # =========================================================================

    # Call messages (request-reply)
    def_call allowed(key : String, max_requests : Int32, window_seconds : Int32), Bool
    def_call retry_after(key : String, window_seconds : Int32), Int32

    # Cast messages (fire-and-forget)
    def_cast shutdown_throttler

    # =========================================================================
    # Actor state
    # =========================================================================

    @instances : Hash(String, LimiterState)
    @last_cleanup : Int64
    @cleanup_interval : Int64
    @instance_ttl : Int64

    def initialize(@name : String = "ThrottlerActor")
      super(@name, mailbox_size: 500)
      @instances = {} of String => LimiterState
      @last_cleanup = Time.utc.to_unix
      @cleanup_interval = QuickHeadlines::Constants::RATE_LIMITER_CLEANUP_INTERVAL.to_i64
      @instance_ttl = QuickHeadlines::Constants::RATE_LIMITER_INSTANCE_TTL.to_i64
    end

    # Singleton access
    @@instance : ThrottlerActor?
    @@instance_mutex = Mutex.new

    def self.instance : ThrottlerActor
      @@instance_mutex.synchronize do
            @@instance ||= ThrottlerActor.new.tap(&.start)
      end
    end

    # =========================================================================
    # Dispatch
    # =========================================================================

    def dispatch(message : Message) : Nil
      case message
      when CallAllowed          then message.deliver_reply(handle_allowed(message.key, message.max_requests, message.window_seconds))
      when CallRetryAfter       then message.deliver_reply(handle_retry_after(message.key, message.window_seconds))
      when CastShutdownThrottler then handle_shutdown
      else raise "Unknown message: #{message.class.name}"
      end
    end

    # =========================================================================
    # Handlers
    # =========================================================================

    private def handle_allowed(key : String, max_requests : Int32, window_seconds : Int32) : Bool
      maybe_cleanup
      now = Time.utc.to_unix

      unless @instances[key]?
        @instances[key] = LimiterState.new(max_requests, window_seconds)
      end

      @instances[key].allowed?(now)
    end

    private def handle_retry_after(key : String, window_seconds : Int32) : Int32
      now = Time.utc.to_unix
      return window_seconds unless state = @instances[key]?
      state.retry_after(now)
    end

    private def handle_shutdown : Nil
      @instances.clear
      Log.for("quickheadlines.ratelimiter").debug { "ThrottlerActor shutdown complete" }
    end

    # =========================================================================
    # Cleanup — runs inside actor loop, no timer fiber needed
    # =========================================================================

    private def maybe_cleanup : Nil
      now = Time.utc.to_unix
      return if (now - @last_cleanup) < @cleanup_interval

      cutoff = now - @instance_ttl
      removed = @instances.size
      @instances.reject! { |_, state| state.last_accessed < cutoff }
      removed -= @instances.size

      Log.for("quickheadlines.ratelimiter").debug { "Cleaned up #{removed} stale rate limiter instances" } if removed > 0
      @last_cleanup = now
    end
  end

  # Backward-compatible API — delegates to ThrottlerActor
  class RateLimiter
    def self.allowed?(key : String, max_requests : Int32 = 60, window_seconds : Int32 = 60) : Bool
      ThrottlerActor.instance.allowed(key, max_requests, window_seconds)
    end

    def self.retry_after(key : String, window_seconds : Int32 = 60) : Int32
      ThrottlerActor.instance.retry_after(key, window_seconds)
    end

    def self.shutdown : Nil
      ThrottlerActor.instance.shutdown_throttler
    end
  end
end
