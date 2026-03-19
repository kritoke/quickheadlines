require "http"
require "time"

module RateLimiter
  class Limiter
    CLEANUP_INTERVAL = 60 # seconds between cleanup runs

    @requests : Hash(String, Array(Time))
    @mutex : Mutex
    @max_requests : Int32
    @window_seconds : Int32
    @last_cleanup : Time?

    def initialize(@max_requests : Int32 = 60, @window_seconds : Int32 = 60)
      @requests = {} of String => Array(Time)
      @mutex = Mutex.new
      @last_cleanup = nil
    end

    def allow?(identifier : String) : Bool
      @mutex.synchronize do
        now = Time.utc
        cleanup_if_needed(now)

        window_start = now - @window_seconds.seconds

        # Get or create request history for this identifier
        history = @requests[identifier] ||= [] of Time

        # Remove old requests outside the window
        history.reject! { |time| time < window_start }

        # Check if under limit
        if history.size < @max_requests
          history << now
          @requests[identifier] = history
          return true
        end

        false
      end
    end

    private def cleanup_if_needed(now : Time) : Nil
      if last_cleanup = @last_cleanup
        return if (now - last_cleanup).total_seconds > CLEANUP_INTERVAL
      end

      @requests.reject! do |_, times_arr|
        times_arr.empty? || times_arr.all? { |time| time < now - @window_seconds.seconds }
      end
      @last_cleanup = now
    end

    def reset(identifier : String)
      @mutex.synchronize do
        @requests.delete(identifier)
      end
    end

    def reset_all
      @mutex.synchronize do
        @requests.clear
      end
    end
  end

  @@instance : Limiter?

  def self.instance : Limiter
    @@instance ||= Limiter.new
  end

  def self.configure(max_requests : Int32, window_seconds : Int32)
    @@instance = Limiter.new(max_requests, window_seconds)
  end
end
