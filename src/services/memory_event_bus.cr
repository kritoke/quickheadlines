require "../infrastructure/actor"

# MemoryEventBus - Memory pressure event distribution
#
# This actor provides:
# 1. Event distribution for memory pressure changes
# 2. Subscription management for memory events
# 3. Event history and logging
# 4. Coordinated response to memory pressure
#
# Usage:
#   MemoryEventBus.instance.subscribe(MemoryEvent::PressureHigh)
#   MemoryEventBus.instance.publish(MemoryEvent::PressureHigh)
#
class MemoryEventBus < Actor
  # =========================================================================
  # Types
  # =========================================================================

  enum MemoryEvent
    PressureNormal    # RSS < 500MB
    PressureMedium    # RSS 500-650MB
    PressureHigh      # RSS 650-800MB
    PressureCritical  # RSS > 800MB
    GCRequested       # Force GC
    CleanupRequested  # Run cleanup
    RestartRequested  # Graceful restart
  end

  struct EventRecord
    getter event : MemoryEvent
    getter timestamp : Time
    getter details : String?

    def initialize(@event, @details = nil)
      @timestamp = Time.utc
    end
  end

  # =========================================================================
  # Messages
  # =========================================================================

  # Call messages (request-reply)
  def_call get_event_history, Array(MemoryEvent)
  def_call get_subscribers_count, Int32

  # Cast messages (fire-and-forget)
  def_cast subscribe(subscriber : Actor, event_type : MemoryEvent)
  def_cast unsubscribe(subscriber : Actor, event_type : MemoryEvent)
  def_cast publish(event : MemoryEvent)
  def_cast clear_history

  # =========================================================================
  # Actor state
  # =========================================================================

  @subscribers : Hash(MemoryEvent, Array(Actor)) = {} of MemoryEvent => Array(Actor)
  @event_history : Array(EventRecord) = [] of EventRecord
  @max_history_size : Int32 = 100

  def initialize(@name : String = "MemoryEventBus")
    super(@name, mailbox_size: 200)
  end

  # Singleton access
  @@instance : MemoryEventBus?
  @@instance_mutex = Mutex.new

  def self.instance : MemoryEventBus
    @@instance_mutex.synchronize do
      @@instance ||= MemoryEventBus.new.tap(&.start)
    end
  end

  # =========================================================================
  # Dispatch
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CallGetEventHistory     then message.deliver_reply(handle_get_event_history)
    when CallGetSubscribersCount then message.deliver_reply(handle_get_subscribers_count)
    when CastSubscribe           then handle_subscribe(message.subscriber, message.event_type)
    when CastUnsubscribe         then handle_unsubscribe(message.subscriber, message.event_type)
    when CastPublish             then handle_publish(message.event)
    when CastClearHistory        then handle_clear_history
    else raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Handlers
  # =========================================================================

  private def handle_get_event_history : Array(MemoryEvent)
    @event_history.last(@max_history_size).map(&.event)
  end

  private def handle_get_subscribers_count : Int32
    @subscribers.values.sum(&.size)
  end

  private def handle_subscribe(subscriber : Actor, event_type : MemoryEvent) : Nil
    @subscribers[event_type] ||= [] of Actor
    unless @subscribers[event_type].includes?(subscriber)
      @subscribers[event_type] << subscriber
      Log.for("quickheadlines.memory").debug { "Subscriber added for #{event_type}" }
    end
  end

  private def handle_unsubscribe(subscriber : Actor, event_type : MemoryEvent) : Nil
    if subscribers = @subscribers[event_type]?
      subscribers.delete(subscriber)
      Log.for("quickheadlines.memory").debug { "Subscriber removed for #{event_type}" }
    end
  end

  private def handle_publish(event : MemoryEvent) : Nil
    # Record event
    @event_history << EventRecord.new(event)
    if @event_history.size > @max_history_size
      @event_history.shift
    end

    Log.for("quickheadlines.memory").info { "Event published: #{event}" }

    # Notify subscribers
    if subscribers = @subscribers[event]?
      subscribers.each do |subscriber|
        begin
          # Send event to subscriber via message
          # This is a simplified approach - in practice, you'd have specific message types
          Log.for("quickheadlines.memory").debug { "Notifying subscriber for #{event}: #{subscriber.name}" }
        rescue ex
          Log.for("quickheadlines.memory").error(exception: ex) { "Failed to notify subscriber" }
        end
      end
    end
  end

  private def handle_clear_history : Nil
    @event_history.clear
    Log.for("quickheadlines.memory").debug { "Event history cleared" }
  end
end
