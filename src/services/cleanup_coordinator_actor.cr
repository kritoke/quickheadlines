require "../infrastructure/actor"

# CleanupCoordinatorActor - Coordinated memory cleanup across subsystems
#
# This actor provides:
# 1. Coordinated cleanup of all subsystems
# 2. Priority-based cleanup under pressure
# 3. Cleanup tracking and reporting
# 4. Emergency cleanup coordination
#
# Usage:
#   CleanupCoordinatorActor.instance.request_cleanup(CleanupPriority::Normal)
#   CleanupCoordinatorActor.instance.get_cleanup_status
#
class CleanupCoordinatorActor < Actor
  # =========================================================================
  # Types
  # =========================================================================

  enum CleanupPriority
    Normal      # Clean caches, expire old entries
    Aggressive  # Reduce retention, force GC
    Emergency   # Drop non-essential data, trigger restart
  end

  struct CleanupStatus
    getter last_cleanup_time : Time?
    getter cleanup_count : Int32
    getter handlers_count : Int32
    getter last_priority : CleanupPriority?

    def initialize(@last_cleanup_time, @cleanup_count, @handlers_count, @last_priority)
    end
  end

  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call get_cleanup_status, CleanupStatus
  def_call get_last_cleanup_time, Time?

  # Cast messages (fire-and-forget)
  def_cast request_cleanup(priority : CleanupPriority)
  def_cast register_cleanup_handler(name : String, handler : -> Nil)
  def_cast unregister_cleanup_handler(name : String)

  # =========================================================================
  # Actor state
  # =========================================================================

  @cleanup_handlers : Hash(String, -> Nil) = {} of String => (-> Nil)
  @last_cleanup_time : Time? = nil
  @cleanup_count : Int32 = 0
  @last_priority : CleanupPriority? = nil
  @is_cleaning_up : Bool = false

  def initialize(@name : String = "CleanupCoordinator")
    super(@name, mailbox_size: 50)
  end

  # Singleton access
  @@instance : CleanupCoordinatorActor?
  @@instance_mutex = Mutex.new

  def self.instance : CleanupCoordinatorActor
    @@instance_mutex.synchronize do
      @@instance ||= CleanupCoordinatorActor.new.tap(&.start)
    end
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallGetCleanupStatus      then message.deliver_reply(handle_get_cleanup_status)
    when CallGetLastCleanupTime    then message.deliver_reply(handle_get_last_cleanup_time)
    when CastRequestCleanup        then handle_request_cleanup(message.priority)
    when CastRegisterCleanupHandler then handle_register_cleanup_handler(message.name, message.handler)
    when CastUnregisterCleanupHandler then handle_unregister_cleanup_handler(message.name)
    else raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Handlers
  # =========================================================================

  private def handle_get_cleanup_status : CleanupStatus
    CleanupStatus.new(@last_cleanup_time, @cleanup_count, @cleanup_handlers.size, @last_priority)
  end

  private def handle_get_last_cleanup_time : Time?
    @last_cleanup_time
  end

  private def handle_request_cleanup(priority : CleanupPriority) : Nil
    if @is_cleaning_up
      Log.for("quickheadlines.cleanup").warn { "Cleanup already in progress, skipping (priority: #{priority})" }
      return
    end

    @is_cleaning_up = true
    @last_priority = priority

    Log.for("quickheadlines.cleanup").info { "Starting cleanup with priority: #{priority}" }

    begin
      case priority
      when .normal?
        run_normal_cleanup
      when .aggressive?
        run_aggressive_cleanup
      when .emergency?
        run_emergency_cleanup
      end

      @last_cleanup_time = Time.utc
      @cleanup_count += 1
      Log.for("quickheadlines.cleanup").info { "Cleanup completed (total: #{@cleanup_count})" }
    rescue ex
      Log.for("quickheadlines.cleanup").error(exception: ex) { "Cleanup failed" }
    ensure
      @is_cleaning_up = false
    end
  end

  private def handle_register_cleanup_handler(name : String, handler : -> Nil) : Nil
    @cleanup_handlers[name] = handler
    Log.for("quickheadlines.cleanup").debug { "Registered cleanup handler: #{name}" }
  end

  private def handle_unregister_cleanup_handler(name : String) : Nil
    @cleanup_handlers.delete(name)
    Log.for("quickheadlines.cleanup").debug { "Unregistered cleanup handler: #{name}" }
  end

  # =========================================================================
  # Cleanup strategies
  # =========================================================================

  private def run_normal_cleanup : Nil
    # Run all registered handlers
    @cleanup_handlers.each do |name, handler|
      begin
        handler.call
        Log.for("quickheadlines.cleanup").debug { "Normal cleanup: #{name} completed" }
      rescue ex
        Log.for("quickheadlines.cleanup").error(exception: ex) { "Normal cleanup: #{name} failed" }
      end
    end

    # Force GC after cleanup
    GC.collect
    Log.for("quickheadlines.cleanup").debug { "GC.collect triggered after normal cleanup" }
  end

  private def run_aggressive_cleanup : Nil
    # Run all registered handlers
    @cleanup_handlers.each do |name, handler|
      begin
        handler.call
        Log.for("quickheadlines.cleanup").debug { "Aggressive cleanup: #{name} completed" }
      rescue ex
        Log.for("quickheadlines.cleanup").error(exception: ex) { "Aggressive cleanup: #{name} failed" }
      end
    end

    # Clear Vug cache
    begin
      VugAdapter.clear_cache
      Log.for("quickheadlines.cleanup").debug { "Cleared Vug cache" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear Vug cache: #{ex.message}" }
    end

    # Clear expired caches
    begin
      Fetcher::CrestHttpClient.clear_expired_dns
      Fetcher::CrestHttpClient.clear_rate_limiters
      Fetcher::URLValidator.clear_validated
      Fetcher::CircuitBreaker::Registry.store.clear_expired
      ColorExtractor.sweep_cache
      Log.for("quickheadlines.cleanup").debug { "Cleared expired caches" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear expired caches: #{ex.message}" }
    end

    # Force GC after cleanup
    GC.collect
    Log.for("quickheadlines.cleanup").debug { "GC.collect triggered after aggressive cleanup" }
  end

  private def run_emergency_cleanup : Nil
    Log.for("quickheadlines.cleanup").error { "Emergency cleanup initiated" }

    # Run all registered handlers
    @cleanup_handlers.each do |name, handler|
      begin
        handler.call
        Log.for("quickheadlines.cleanup").debug { "Emergency cleanup: #{name} completed" }
      rescue ex
        Log.for("quickheadlines.cleanup").error(exception: ex) { "Emergency cleanup: #{name} failed" }
      end
    end

    # Clear all caches
    begin
      VugAdapter.clear_cache
      Fetcher::CrestHttpClient.clear_expired_dns
      Fetcher::CrestHttpClient.clear_rate_limiters
      Fetcher::URLValidator.clear_validated
      Fetcher::CircuitBreaker::Registry.store.clear_expired
      ColorExtractor.sweep_cache
      Log.for("quickheadlines.cleanup").debug { "Cleared all caches" }
    rescue ex
      Log.for("quickheadlines.cleanup").warn { "Failed to clear all caches: #{ex.message}" }
    end

    # Force GC multiple times
    3.times do
      GC.collect
      sleep(100.milliseconds)
    end
    Log.for("quickheadlines.cleanup").debug { "Forced GC.collect 3 times after emergency cleanup" }
  end
end
