require "time"
require "mutex"

module Quickheadlines
  class RateLimiter
    @@instances = {} of String => RateLimiter
    @@cleanup_lock = Mutex.new
    @@last_cleanup = Time.utc

    property max_requests : Int32
    property window_seconds : Int32
    property requests : Hash(String, Array(Int64))

    def initialize(@max_requests : Int32 = 60, @window_seconds : Int32 = 60)
      @requests = Hash(String, Array(Int64)).new
    end

    def self.get_or_create(key : String, max_requests : Int32 = 1, window_seconds : Int32 = 60) : RateLimiter
      unless @@instances[key]?
        @@instances[key] = RateLimiter.new(max_requests, window_seconds)
      end
      @@instances[key]
    end

    def self.cleanup_stale_entries
      @@cleanup_lock.synchronize do
        now = Time.utc
        return if (now - @@last_cleanup).total_seconds < 60

        @@instances.each do |_, limiter|
          limiter.cleanup
        end
        @@last_cleanup = now
      end
    end

    def cleanup
      cutoff = Time.utc.to_unix - @window_seconds
      @requests.each do |key, times|
        @requests[key] = times.select { |_t| _t > cutoff }
      end
      @requests.reject! { |_, _times| _times.empty? }
    end

    def allowed?(identifier : String) : Bool
      self.class.cleanup_stale_entries

      now = Time.utc.to_unix
      cutoff = now - @window_seconds

      times = @requests[identifier]? || [] of Int64
      times = times.select { |_t| _t > cutoff }

      if times.size >= @max_requests
        return false
      end

      times << now
      @requests[identifier] = times
      true
    end

    def retry_after(identifier : String) : Int32
      times = @requests[identifier]?
      return @window_seconds if times.nil? || times.empty?

      oldest = times.min
      now = Time.utc.to_unix
      elapsed = now - oldest
      [@window_seconds - elapsed, 1].max
    end

    def self.reset(key : String)
      @@instances.delete(key)
    end

    def self.reset_all
      @@instances.clear
    end
  end
end
