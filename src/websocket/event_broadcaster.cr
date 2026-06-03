require "channel"
require "json"
require "./socket_manager"

class EventBroadcaster
  # All shared state accessed only through the broadcaster fiber loop.
  # @mutex protects state reads (writer fibers and API callers) from
  # concurrent modification by the broadcaster fiber.
  @@mutex = Mutex.new(:unchecked)
  @@subscribers = [] of SubscribeMessage
  @@clients = [] of HTTP::WebSocket

  UPDATE_CHANNEL    = Channel(FeedUpdateEvent).new(QuickHeadlines::Constants::WEBSOCKET_CHANNEL_SIZE)
  SHUTDOWN_CHANNEL  = Channel(Nil).new(1)
  DROPPED_EVENTS    = Atomic(Int64).new(0)
  PROCESSED_EVENTS   = Atomic(Int64).new(0)
  SENT_EVENTS        = Atomic(Int64).new(0)

  # Track client history for leak diagnosis
  @@client_history = [] of {time: Time, count: Int32}
  @@history_max_entries = 1000  # Keep last ~8 hours at 30s intervals

  def self.start : Nil
    spawn(name: "event-broadcaster") do
      loop do
        begin
          select
          when event = UPDATE_CHANNEL.receive?
            begin
              json = event.to_json
              broadcast_json(json)
              SENT_EVENTS.add(1)
              PROCESSED_EVENTS.add(1)
            rescue ex
              Log.for("quickheadlines.websocket").error(exception: ex) { "EventBroadcaster broadcast error, dropping event" }
            end
          when timeout(QuickHeadlines::Constants::WEBSOCKET_HEARTBEAT_SECONDS.seconds)
            begin
              json = HeartbeatEvent.new.to_json
              broadcast_json(json)
              SENT_EVENTS.add(1)
              # Log client count every heartbeat (every 30s)
              log_client_stats
            rescue ex
              Log.for("quickheadlines.websocket").error(exception: ex) { "EventBroadcaster heartbeat error" }
            end
          when SHUTDOWN_CHANNEL.receive?
            UPDATE_CHANNEL.close
            shutdown_all
            Log.for("quickheadlines.websocket").info { "EventBroadcaster shut down" }
            break
          end
        rescue ex
          Log.for("quickheadlines.websocket").error(exception: ex) { "EventBroadcaster loop error" }
        end
      end
    end
    Log.for("quickheadlines.websocket").info { "EventBroadcaster started" }
  end

  private def self.log_client_stats : Nil
    client_count = @@mutex.synchronize { @@clients.size }
    
    # Record history
    @@client_history << {time: Time.utc, count: client_count}
    @@client_history.shift if @@client_history.size > @@history_max_entries
    
    # Log if count is unexpected
    if client_count > 50
      Log.for("quickheadlines.websocket").warn { "EventBroadcaster: high client count #{client_count} (possible leak)" }
    elsif client_count > 100
      Log.for("quickheadlines.websocket").error { "EventBroadcaster: VERY HIGH client count #{client_count} (LEAK)" }
    end
  end

  def self.client_count : Int32
    @@mutex.synchronize { @@clients.size }
  end

  def self.client_history_summary : String
    return "No history" if @@client_history.empty?
    recent = @@client_history.last(10)
    counts = recent.map(&.[:count])
    "min=#{counts.min}, max=#{counts.max}, current=#{counts.last}"
  end

  # Broadcast JSON to all active clients and subscribers.
  # All access to @clients and @subscribers goes through @@mutex so that
  # API callers (stats, subscribe, unsubscribe) can read safely while the
  # broadcaster fiber modifies the arrays.
  private def self.broadcast_json(json : String) : Nil
    @@mutex.synchronize do
      # Send to WebSocket clients
      @@clients.each do |client|
        begin
          client.send(json)
        rescue IO::Error | Channel::ClosedError
          @@clients.delete(client)
        end
      end
      # Notify subscriber channels
      @@subscribers.each do |sub|
        begin
          sub.channel.send(json)
        rescue Channel::ClosedError
          @@subscribers.delete(sub)
        end
      end
    end
  end

  def self.notify_feed_update(timestamp : Int64) : Nil
    event = FeedUpdateEvent.new(timestamp)
    begin
      select
      when UPDATE_CHANNEL.send(event)
        # Queued
      when timeout(QuickHeadlines::Constants::WEBSOCKET_SEND_TIMEOUT_MS.milliseconds)
        DROPPED_EVENTS.add(1)
        Log.for("quickheadlines.websocket").warn { "Channel full, dropping event (buffer: #{QuickHeadlines::Constants::WEBSOCKET_CHANNEL_SIZE})" }
      end
    rescue Channel::ClosedError
      Log.for("quickheadlines.websocket").error { "Channel closed" }
    rescue ex
      DROPPED_EVENTS.add(1)
      Log.for("quickheadlines.websocket").error(exception: ex) { "Channel error" }
    end
  end

  def self.stats
    @@mutex.synchronize do
      {
        "sent"        => SENT_EVENTS.get.to_i64,
        "dropped"     => DROPPED_EVENTS.get.to_i64,
        "processed"   => PROCESSED_EVENTS.get.to_i64,
        "clients"     => @@clients.size.to_i64,
        "subscribers"  => @@subscribers.size.to_i64,
      }
    end
  end

  # Subscribe a channel to real-time events. Returns the channel to receive events.
  def self.subscribe(channel : Channel(String)) : SubscribeMessage
    msg = SubscribeMessage.new(channel)
    @@mutex.synchronize { @@subscribers << msg }
    msg
  end

  def self.unsubscribe(msg : SubscribeMessage) : Nil
    @@mutex.synchronize { @@subscribers.delete(msg) }
  end

  def self.add_client(client : HTTP::WebSocket) : Nil
    @@mutex.synchronize { @@clients << client }
  end

  def self.remove_client(client : HTTP::WebSocket) : Nil
    @@mutex.synchronize { @@clients.delete(client) }
  end

  def self.shutdown : Nil
    select
    when SHUTDOWN_CHANNEL.send(nil)
    when timeout(2.seconds)
      Log.for("quickheadlines.websocket").warn { "SHUTDOWN_CHANNEL send timed out" }
    end
  rescue Channel::ClosedError
    # Already closed — ignore
  end

  def self.close_update_channel : Nil
    UPDATE_CHANNEL.close
  rescue Channel::ClosedError
    # Already closed
  end

  private def self.shutdown_all : Nil
    @@mutex.synchronize do
      @@clients.each do |client|
        begin
          client.close
        rescue IO::Error
        end
      end
      @@clients.clear
      @@subscribers.each do |sub|
        sub.channel.close
      end
      @@subscribers.clear
    end
  end
end

struct FeedUpdateEvent
  getter timestamp : Int64
  getter type : String

  def initialize(@timestamp)
    @type = "feed_update"
  end

  def to_json : String
    {type: @type, timestamp: @timestamp}.to_json
  end
end

struct HeartbeatEvent
  getter timestamp : Int64
  getter type : String

  def initialize
    @timestamp = Time.utc.to_unix_ms
    @type = "heartbeat"
  end

  def to_json : String
    {type: @type, timestamp: @timestamp}.to_json
  end
end

struct SubscribeMessage
  getter channel : Channel(String)

  def initialize(@channel)
  end
end