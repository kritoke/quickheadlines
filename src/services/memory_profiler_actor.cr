require "../infrastructure/actor"

# MemoryProfilerActor - Detailed memory profiling
#
# This actor provides:
# 1. Memory profiling for code blocks
# 2. Allocation tracking
# 3. Memory hotspot detection
# 4. Profiling reports
#
# Usage:
#   MemoryProfilerActor.instance.start_profile("feed_fetch")
#   # ... operation
#   MemoryProfilerActor.instance.end_profile("feed_fetch")
#   MemoryProfilerActor.instance.get_profile_results
#
class MemoryProfilerActor < Actor
  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call get_profile_results, Array(ProfileEntry)
  def_call get_profile_summary, ProfileSummary

  # Cast messages (fire-and-forget)
  def_cast start_profile(name : String)
  def_cast end_profile(name : String)
  def_cast reset_profiles

  # =========================================================================
  # Types
  # =========================================================================

  struct ProfileEntry
    getter name : String
    getter calls : Int32
    getter total_bytes : Int64
    getter avg_bytes : Int64
    getter last_start_rss : Float64
    getter last_end_rss : Float64
    getter last_delta_mb : Float64

    def initialize(@name, @calls, @total_bytes, @last_start_rss, @last_end_rss)
      @avg_bytes = calls > 0 ? total_bytes // calls : 0_i64
      @last_delta_mb = (@last_end_rss - @last_start_rss).round(2)
    end
  end

  struct ProfileSummary
    getter total_profiles : Int32
    getter total_calls : Int32
    getter total_bytes : Int64
    getter biggest_consumer : String?
    getter biggest_delta_mb : Float64

    def initialize(@total_profiles, @total_calls, @total_bytes, @biggest_consumer, @biggest_delta_mb)
    end
  end

  # =========================================================================
  # Actor state
  # =========================================================================

  @profiles : Hash(String, ProfileData) = {} of String => ProfileData
  @active_profiles : Hash(String, Float64) = {} of String => Float64

  struct ProfileData
    property calls : Int32 = 0
    property total_bytes : Int64 = 0_i64
    property last_start_rss : Float64 = 0.0
    property last_end_rss : Float64 = 0.0
  end

  def initialize(@name : String = "MemoryProfiler")
    super(@name, mailbox_size: 100)
  end

  # Singleton access
  @@instance : MemoryProfilerActor?
  @@instance_mutex = Mutex.new

  def self.instance : MemoryProfilerActor
    @@instance_mutex.synchronize do
      @@instance ||= MemoryProfilerActor.new.tap(&.start)
    end
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallGetProfileResults then message.deliver_reply(handle_get_profile_results)
    when CallGetProfileSummary then message.deliver_reply(handle_get_profile_summary)
    when CastStartProfile      then handle_start_profile(message.name)
    when CastEndProfile        then handle_end_profile(message.name)
    when CastResetProfiles     then handle_reset_profiles
    else                            raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Handlers
  # =========================================================================

  private def handle_get_profile_results : Array(ProfileEntry)
    @profiles.map do |name, data|
      ProfileEntry.new(
        name: name,
        calls: data.calls,
        total_bytes: data.total_bytes,
        last_start_rss: data.last_start_rss,
        last_end_rss: data.last_end_rss
      )
    end
  end

  private def handle_get_profile_summary : ProfileSummary
    total_profiles = @profiles.size
    total_calls = @profiles.values.sum(&.calls)
    total_bytes = @profiles.values.sum(&.total_bytes)

    biggest_consumer = @profiles.max_by? { |_, data| data.total_bytes }
    biggest_delta = @profiles.values.max_of? { |data| (data.last_end_rss - data.last_start_rss).abs } || 0.0

    ProfileSummary.new(
      total_profiles: total_profiles,
      total_calls: total_calls,
      total_bytes: total_bytes,
      biggest_consumer: biggest_consumer.try(&.[0]),
      biggest_delta_mb: biggest_delta.round(2)
    )
  end

  private def handle_start_profile(name : String) : Nil
    rss = read_rss_mb
    @active_profiles[name] = rss
    Log.for("quickheadlines.memory").debug { "Started profile: #{name} at RSS=#{rss.round(1)}MB" }
  end

  private def handle_end_profile(name : String) : Nil
    start_rss = @active_profiles.delete(name)
    return unless start_rss

    end_rss = read_rss_mb
    delta = end_rss - start_rss

    # Update profile data
    data = @profiles[name]? || ProfileData.new
    data.calls += 1
    data.total_bytes += (delta * 1024 * 1024).to_i64
    data.last_start_rss = start_rss
    data.last_end_rss = end_rss
    @profiles[name] = data

    Log.for("quickheadlines.memory").debug { "Ended profile: #{name}, delta=#{delta.round(2)}MB" }
  end

  private def handle_reset_profiles : Nil
    @profiles.clear
    @active_profiles.clear
    Log.for("quickheadlines.memory").info { "Profiles reset" }
  end

  private def read_rss_mb : Float64
    begin
      {% if flag?(:freebsd) %}
        if File.exists?("/proc/curproc/status")
          status = File.read("/proc/curproc/status")
          if match = status.match(/VmRSS:\s+(\d+)\s+kB/)
            return match[1].to_f64 / 1024.0
          end
        end
      {% end %}

      gc_stats = GC.stats
      gc_stats.heap_size.to_f64 / (1024.0 * 1024.0)
    rescue ex
      0.0
    end
  end
end
