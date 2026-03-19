require "http"
require "time"

module RateLimiter
  class Limiter
    @requests : Hash(String, Array(Time))
    @mutex : Mutex
    @max_requests : Int32
    @window_seconds : Int32

    def initialize(@max_requests : Int32 = 60, @window_seconds : Int32 = 60)
      @requests = {} of String => Array(Time)
      @mutex = Mutex.new
    end

    def allow?(identifier : String) : Bool
      @mutex.synchronize do
        now = Time.utc
        window_start = now - @window_seconds.seconds

        # Get or create request history for this identifier
        history = @requests[identifier] ||= [] of Time

        # Remove old requests outside the window
        history.reject! { |t| t < window_start }

        # Check if under limit
        if history.size < @max_requests
          history << now
          @requests[identifier] = history
          return true
        end

        false
      end
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
