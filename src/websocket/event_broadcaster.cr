require "channel"
require "json"
require "./socket_manager"

class EventBroadcaster
  UPDATE_CHANNEL   = Channel(FeedUpdateEvent).new(100)
  DROPPED_EVENTS   = Atomic(Int64).new(0)
  PROCESSED_EVENTS = Atomic(Int64).new(0)

  def self.start : Nil
    spawn do
      loop do
        select
        when event = UPDATE_CHANNEL.receive?
          SocketManager.instance.broadcast(event.to_json)
          PROCESSED_EVENTS.add(1)
        when timeout(30.seconds)
          SocketManager.instance.broadcast(HeartbeatEvent.new.to_json)
        end
      end
    end
    STDERR.puts "[EventBroadcaster] Started"
  end

  def self.notify_feed_update(timestamp : Int64) : Nil
    event = FeedUpdateEvent.new(timestamp)
    begin
      select
      when UPDATE_CHANNEL.send(event)
        PROCESSED_EVENTS.add(1)
      when timeout(10.milliseconds)
        DROPPED_EVENTS.add(1)
        STDERR.puts "[EventBroadcaster] Channel full, dropping event (buffer size: 100)"
      end
    rescue Channel::ClosedError
      STDERR.puts "[EventBroadcaster] Channel closed, cannot send update"
    rescue ex
      DROPPED_EVENTS.add(1)
      STDERR.puts "[EventBroadcaster] Channel error, event dropped: #{ex.class}"
    end
  end

  def self.stats
    {
      "dropped"   => DROPPED_EVENTS.get,
      "processed" => PROCESSED_EVENTS.get,
    }
  end
end

struct FeedUpdateEvent
  include JSON::Serializable

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
  include JSON::Serializable

  property timestamp : Int64
  property type : String

  def initialize
    @timestamp = Time.local.to_unix_ms
    @type = "heartbeat"
  end

  def to_json : String
    {type: "heartbeat", timestamp: @timestamp}.to_json
  end
end
