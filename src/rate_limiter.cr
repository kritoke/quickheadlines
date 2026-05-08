require "time"
require "mutex"

module QuickHeadlines
  class RateLimiter
    @@instances = {} of String => RateLimiter
    @@cleanup_lock = Mutex.new
    @@cleanup_fiber : Fiber?
    @@last_cleanup = Time.utc

    property max_requests : Int32
    property window_seconds : Int32
    property requests : Hash(String, Array(Int64))
    property last_accessed : Int64

    def initialize(@max_requests : Int32 = 60, @window_seconds : Int32 = 60)
      @requests = Hash(String, Array(Int64)).new
      @mutex = Mutex.new
      @last_accessed = Time.utc.to_unix
    end

    def self.start_cleanup_fiber
      @@cleanup_lock.synchronize do
        return if @@cleanup_fiber
        @@cleanup_fiber = spawn do
          loop do
            sleep QuickHeadlines::Constants::RATE_LIMITER_CLEANUP_INTERVAL.seconds
            break if QuickHeadlines.shutting_down?
            begin
              cleanup_stale_instances
            rescue ex
              Log.for("quickheadlines.ratelimiter").error(exception: ex) { "Cleanup error" }
            end
          end
        end
      end
    end

    def self.get_or_create(key : String, max_requests : Int32 = 1, window_seconds : Int32 = 60) : RateLimiter
      start_cleanup_fiber
      @@cleanup_lock.synchronize do
        unless @@instances[key]?
          @@instances[key] = RateLimiter.new(max_requests, window_seconds)
        end
        instance = @@instances[key]
        instance.last_accessed = Time.utc.to_unix
        instance
      end
    end

    def self.cleanup_stale_instances
      @@cleanup_lock.synchronize do
        now = Time.utc
        return if (now - @@last_cleanup).total_seconds < QuickHeadlines::Constants::RATE_LIMITER_CLEANUP_INTERVAL

        cutoff = now.to_unix - QuickHeadlines::Constants::RATE_LIMITER_INSTANCE_TTL
        @@instances.reject! do |_, limiter|
          limiter.last_accessed < cutoff
        end
        @@last_cleanup = now
      end
    end

    def cleanup
      @mutex.synchronize do
        cutoff = Time.utc.to_unix - @window_seconds
        @requests.each do |key, times|
          @requests[key] = times.select { |_t| _t > cutoff }
        end
        @requests.reject! { |_, _times| _times.empty? }
      end
    end

    def allowed?(identifier : String) : Bool
      now = Time.utc.to_unix
      cutoff = now - @window_seconds

      @mutex.synchronize do
        times = @requests[identifier]? || [] of Int64
        times = times.select { |_t| _t > cutoff }

        if times.size >= @max_requests
          return false
        end

        times << now
        @requests[identifier] = times
        true
      end
    end

    def retry_after(identifier : String) : Int32
      @mutex.synchronize do
        times = @requests[identifier]?
        return @window_seconds if times.nil? || times.empty?

        oldest = times.min
        now = Time.utc.to_unix
        elapsed = now - oldest
        return [@window_seconds - elapsed, 1].max
      end
    end
  end
end
