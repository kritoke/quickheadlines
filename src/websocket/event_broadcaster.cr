require "channel"
require "json"
require "./socket_manager"

class EventBroadcaster
  UPDATE_CHANNEL   = Channel(FeedUpdateEvent).new(QuickHeadlines::Constants::WEBSOCKET_CHANNEL_SIZE)
  SHUTDOWN_CHANNEL = Channel(Nil).new(1)
  DROPPED_EVENTS   = Atomic(Int64).new(0)
  PROCESSED_EVENTS = Atomic(Int64).new(0)

  def self.start : Nil
    spawn do
      loop do
        select
        when event = UPDATE_CHANNEL.receive?
          SocketManager.instance.broadcast(event.to_json)
          PROCESSED_EVENTS.add(1)
        when timeout(QuickHeadlines::Constants::WEBSOCKET_HEARTBEAT_SECONDS.seconds)
          SocketManager.instance.broadcast(HeartbeatEvent.new.to_json)
        when SHUTDOWN_CHANNEL.receive?
          UPDATE_CHANNEL.close
          Log.for("quickheadlines.websocket").info { "EventBroadcaster shutting down" }
          break
        end
      end
    end
    Log.for("quickheadlines.websocket").info { "EventBroadcaster started" }
  end

  def self.notify_feed_update(timestamp : Int64) : Nil
    event = FeedUpdateEvent.new(timestamp)
    begin
      select
      when UPDATE_CHANNEL.send(event)
        # Event queued for broadcast
      when timeout(QuickHeadlines::Constants::WEBSOCKET_SEND_TIMEOUT_MS.milliseconds)
        DROPPED_EVENTS.add(1)
        Log.for("quickheadlines.websocket").warn { "Channel full, dropping event (buffer size: #{QuickHeadlines::Constants::WEBSOCKET_CHANNEL_SIZE})" }
      end
    rescue Channel::ClosedError
      Log.for("quickheadlines.websocket").error { "Channel closed, cannot send update" }
    rescue ex
      DROPPED_EVENTS.add(1)
      Log.for("quickheadlines.websocket").error(exception: ex) { "Channel error, event dropped: #{ex.class}" }
    end
  end

  def self.stats
    {
      "dropped"   => DROPPED_EVENTS.get,
      "processed" => PROCESSED_EVENTS.get,
    }
  end

  def self.shutdown : Nil
    SHUTDOWN_CHANNEL.send(nil)
  end

  # Force close the update channel to unblock any waiting fibers
  def self.close_update_channel : Nil
    UPDATE_CHANNEL.close
  rescue Channel::ClosedError
    # Already closed
  end
end

struct FeedUpdateEvent
  property timestamp : Int64
  property type : String

  def initialize(@timestamp : Int64)
    @type = "feed_update"
  end

  def to_json : String
    {type: "feed_update", timestamp: @timestamp}.to_json
  end
end

struct HeartbeatEvent
  property timestamp : Int64
  property type : String

  def initialize
    @timestamp = Time.utc.to_unix_ms
    @type = "heartbeat"
  end

  def to_json : String
    {type: "heartbeat", timestamp: @timestamp}.to_json
  end
end
