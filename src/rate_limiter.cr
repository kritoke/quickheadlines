require "time"
require "mutex"

module Quickheadlines
  module RateLimiting
    class RateLimitInfo
      property request_count : Int32
      property window_start : Time
      property category : String

      def initialize(@category : String)
        @request_count = 0
        @window_start = Time.utc
      end

      def expired?(window_size : Time::Span) : Bool
        (Time.utc - @window_start) > window_size * 2
      end
    end

    class RateLimiter
      @@instance : RateLimiter?
      @@mutex = Mutex.new

      MAX_ENTRIES      = 10_000
      CLEANUP_INTERVAL = 5.minutes

      def self.instance : RateLimiter
        @@mutex.synchronize { @@instance ||= new }
      end

      @limits : Hash(String, RateLimitInfo)
      @cleanup_task : Fiber?
      @running : Bool

      def initialize
        @limits = Hash(String, RateLimitInfo).new
        @running = true
        @cleanup_task = spawn cleanup_loop
        STDERR.puts "[#{Time.local}] Rate limiter initialized"
      end

      def check_limit(ip : String, category : String) : {allowed: Bool, remaining: Int32, reset_at: Int64}
        window_size = RateLimitConfig.window_size(category)
        limit = RateLimitConfig.limit(category)
        window_key = "#{ip}:#{category}"

        info = @@mutex.synchronize do
          existing = @limits[window_key]? 
          if existing
            if existing.expired?(window_size)
              @limits.delete(window_key)
              RateLimitInfo.new(category)
            else
              existing
            end
          else
            RateLimitInfo.new(category).tap { |i| @limits[window_key] = i }
          end
        end

        if info.request_count >= limit
          reset_at = info.window_start.to_unix + window_size.total_seconds.to_i64
          return {allowed: false, remaining: 0, reset_at: reset_at}
        end

        info.request_count += 1
        remaining = limit - info.request_count
        reset_at = info.window_start.to_unix + window_size.total_seconds.to_i64

        {allowed: true, remaining: remaining, reset_at: reset_at}
      end

      def should_rate_limit?(ip : String, category : String) : Bool
        !check_limit(ip, category)[:allowed]
      end

      def stop
        @running = false
      end

      def stats : {total_entries: Int32, by_category: Hash(String, Int32)}
        categories = Hash(String, Int32).new(0)
        @@mutex.synchronize do
          @limits.each do |_, info|
            categories[info.category] += 1
          end
          {total_entries: @limits.size, by_category: categories}
        end
      end

      private def cleanup_loop
        loop do
          sleep CLEANUP_INTERVAL
          break unless @running
          cleanup_expired_entries
        end
      rescue ex
        STDERR.puts "[#{Time.local}] Rate limiter cleanup error: #{ex.message}"
      end

      private def cleanup_expired_entries
        removed = 0
        @@mutex.synchronize do
          @limits.reject! do |_, info|
            window_size = RateLimitConfig.window_size(info.category)
            info.expired?(window_size)
          end
          removed = @limits.size
        end
        STDERR.puts "[#{Time.local}] Rate limit cleanup: #{removed} active entries"
      end
    end

    module RateLimitConfig
      DEFAULT_LIMITS = {
        "expensive"      => 5,
        "moderately"     => 10,
        "read"           => 60,
        "very_expensive" => 3,
      }

      DEFAULT_WINDOWS = {
        "expensive"      => 1.hour,
        "moderately"     => 1.hour,
        "read"           => 1.minute,
        "very_expensive" => 1.hour,
      }

      @@custom_limits : Hash(String, Int32)? = nil
      @@custom_windows : Hash(String, Time::Span)? = nil

      def self.custom_limits=(limits : Hash(String, Int32))
        @@custom_limits = limits
      end

      def self.custom_windows=(windows : Hash(String, Time::Span))
        @@custom_windows = windows
      end

      def self.limit(category : String) : Int32
        if limits = @@custom_limits
          return limits[category] if limits.has_key?(category)
        end
        DEFAULT_LIMITS[category]
      end

      def self.window_size(category : String) : Time::Span
        if windows = @@custom_windows
          return windows[category] if windows.has_key?(category)
        end
        DEFAULT_WINDOWS[category]
      end

      def self.get_category(endpoint : String) : String
        case endpoint
        when "/api/cluster", "/api/recluster"
          "expensive"
        when "/api/refresh", "/api/clear-cache"
          "moderately"
        when "/api/cleanup-orphaned"
          "very_expensive"
        else
          "read"
        end
      end
    end
  end
end

def rate_limiter : Quickheadlines::RateLimiting::RateLimiter
  Quickheadlines::RateLimiting::RateLimiter.instance
end
