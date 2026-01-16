require "time"
require "./config"

# Health monitoring utilities for tracking system resources and detecting issues
module HealthMonitor
  # Configuration
  LOG_INTERVAL             = 5.minutes
  CPU_WARNING_THRESHOLD    = 80.0              # 80% CPU usage
  MEMORY_WARNING_THRESHOLD = 500 * 1024 * 1024 # 500MB
  FIBER_WARNING_THRESHOLD  = 1000              # 1000 fibers
  FEED_TIMEOUT_THRESHOLD   =    3              # Number of timeouts before marking feed as slow
  FEED_COOLDOWN_PERIOD     = 30.minutes        # Cooldown before re-enabling disabled feeds

  # Metrics tracking
  @@last_cpu_time : Process::Tms?
  @@last_check_time = Time.local
  @@cache_hits = 0
  @@cache_misses = 0
  @@db_query_times = [] of Float64
  @@db_query_count = 0

  # Feed health tracking
  @@feed_health : Hash(String, FeedHealth) = Hash(String, FeedHealth).new
  @@feed_health_mutex = Mutex.new
  @@disabled_feeds : Hash(String, Time) = Hash(String, Time).new

  # Log current system health metrics
  def self.log_health_metrics
    now = Time.local
    cpu_usage = calculate_cpu_usage

    # Calculate cache hit rate
    total_cache_ops = @@cache_hits + @@cache_misses
    cache_hit_rate = total_cache_ops > 0 ? (@@cache_hits / total_cache_ops * 100).round(2) : 0.0

    # Calculate average DB query time
    avg_db_time = @@db_query_count > 0 ? (@@db_query_times.sum / @@db_query_count).round(2) : 0.0

    # Log metrics
    STDERR.puts "[#{now}] Health Metrics:"
    STDERR.puts "  CPU Usage: #{cpu_usage.round(2)}% #{cpu_usage > CPU_WARNING_THRESHOLD ? "[WARNING]" : ""}"
    STDERR.puts "  Cache Hit Rate: #{cache_hit_rate}% (hits: #{@@cache_hits}, misses: #{@@cache_misses})"
    STDERR.puts "  DB Queries: #{@@db_query_count} (avg time: #{avg_db_time}ms)"

    # Reset counters for next interval
    @@cache_hits = 0
    @@cache_misses = 0
    @@db_query_times.clear
    @@db_query_count = 0
  end

  # Start periodic health monitoring
  def self.start_monitoring
    spawn do
      loop do
        sleep LOG_INTERVAL
        log_health_metrics
      end
    end
  end

  # Track cache hit
  def self.record_cache_hit
    @@cache_hits += 1
  end

  # Track cache miss
  def self.record_cache_miss
    @@cache_misses += 1
  end

  # Track database query time
  def self.record_db_query(time_ms : Float64)
    @@db_query_times << time_ms
    @@db_query_count += 1

    # Keep only last 100 query times to avoid memory growth
    @@db_query_times.shift if @@db_query_times.size > 100
  end

  # Calculate CPU usage since last check
  private def self.calculate_cpu_usage : Float64
    current_cpu = Process.times
    current_time = Time.local

    if last_cpu = @@last_cpu_time
      time_delta = (current_time - @@last_check_time).total_seconds
      return 0.0 if time_delta == 0

      user_delta = current_cpu.utime - last_cpu.utime
      system_delta = current_cpu.stime - last_cpu.stime
      total_delta = user_delta + system_delta

      cpu_usage = (total_delta / time_delta) * 100.0
      cpu_usage = [cpu_usage, 0.0].max
      cpu_usage = [cpu_usage, 100.0].min
    else
      cpu_usage = 0.0
    end

    @@last_cpu_time = current_cpu
    @@last_check_time = current_time

    cpu_usage
  end

  # Format bytes to human-readable string
  private def self.format_bytes(bytes : Int64) : String
    units = ["B", "KB", "MB", "GB"]
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.size - 1
      size /= 1024
      unit_index += 1
    end

    rounded = size.round(2)
    if rounded == rounded.to_i
      "#{rounded.to_i} #{units[unit_index]}"
    else
      "#{rounded} #{units[unit_index]}"
    end
  end

  # Log error with context
  def self.log_error(context : String, exception : Exception)
    STDERR.puts "[#{Time.local}] ERROR in #{context}: #{exception.class} - #{exception.message}"
    STDERR.puts exception.backtrace.first(10).join("\n")
  end

  # Log warning
  def self.log_warning(message : String)
    STDERR.puts "[#{Time.local}] WARNING: #{message}"
  end

  # Log info
  def self.log_info(message : String)
    STDERR.puts "[#{Time.local}] INFO: #{message}"
  end

  # ============================================
  # Feed Health Tracking
  # ============================================

  # Update feed health status
  def self.update_feed_health(url : String, status : FeedHealthStatus, response_time : Float64? = nil)
    @@feed_health_mutex.synchronize do
      existing = @@feed_health[url]?

      new_status = status
      consecutive_failures = existing ? existing.consecutive_failures : 0
      last_success = existing ? existing.last_success : nil
      last_failure = existing ? existing.last_failure : nil
      avg_response_time = existing ? existing.average_response_time : (response_time || 0.0)

      case status
      when FeedHealthStatus::Healthy
        consecutive_failures = 0
        last_success = Time.local
        # Update average response time
        if response_time && existing
          avg_response_time = (avg_response_time * 0.7) + (response_time * 0.3)
        elsif response_time
          avg_response_time = response_time
        end
      when FeedHealthStatus::Timeout, FeedHealthStatus::Unreachable
        consecutive_failures += 1
        last_failure = Time.local

        # Mark feed as slow if too many timeouts
        if consecutive_failures >= FEED_TIMEOUT_THRESHOLD
          new_status = FeedHealthStatus::Slow
        end
      else
        # Slow status - maintain failure count but don't increment
        last_failure = Time.local
      end

      @@feed_health[url] = FeedHealth.new(
        url: url,
        status: new_status,
        last_success: last_success,
        last_failure: last_failure,
        consecutive_failures: consecutive_failures,
        average_response_time: avg_response_time
      )

      # Log status change
      if existing.nil? || existing.status != new_status
        log_info("Feed health updated: #{url} -> #{new_status} (failures: #{consecutive_failures})")
      end
    end
  end

  # Check if a feed is disabled (due to repeated failures)
  def self.feed_disabled?(url : String) : Bool
    @@feed_health_mutex.synchronize do
      if disabled_time = @@disabled_feeds[url]?
        # Check if cooldown period has passed
        if Time.local - disabled_time > FEED_COOLDOWN_PERIOD
          @@disabled_feeds.delete(url)
          return false
        end
        return true
      end
      false
    end
  end

  # Temporarily disable a feed due to repeated failures
  def self.disable_feed(url : String)
    @@feed_health_mutex.synchronize do
      @@disabled_feeds[url] = Time.local
      log_warning("Feed disabled due to repeated failures: #{url} (will retry after #{FEED_COOLDOWN_PERIOD})")
    end
  end

  # Get feed health status
  def self.get_feed_health(url : String) : FeedHealth?
    @@feed_health_mutex.synchronize do
      @@feed_health[url]?
    end
  end

  # Get all feed health statuses
  def self.all_feed_health : Array(FeedHealth)
    @@feed_health_mutex.synchronize do
      @@feed_health.values
    end
  end

  # Log all feed health statuses
  def self.log_feed_health
    health = all_feed_health
    return if health.empty?

    STDERR.puts "[#{Time.local}] Feed Health Status:"
    health.each do |feed|
      disabled = feed_disabled?(feed.url) ? " [DISABLED]" : ""
      STDERR.puts "  #{feed.url}: #{feed.status}#{disabled} (failures: #{feed.consecutive_failures}, avg response: #{feed.average_response_time.round(2)}ms)"
    end
  end
end
