require "../spec_helper"

describe EventBroadcaster do
  describe ".start" do
    it "starts broadcaster without errors" do
      EventBroadcaster.start
      # Test passes if no exception
      true.should be_true
    end
  end

  describe ".notify_feed_update" do
    it "sends event without raising" do
      EventBroadcaster.notify_feed_update(1234567890)
      # Test passes if no exception
      true.should be_true
    end

    it "handles multiple rapid notifications" do
      100.times do |i|
        EventBroadcaster.notify_feed_update(1234567890 + i)
      end
      # Test passes if no exception
      true.should be_true
    end

    it "completes quickly" do
      start_time = Time.monotonic

      1000.times do |i|
        EventBroadcaster.notify_feed_update(1234567890 + i)
      end

      elapsed = Time.monotonic - start_time
      # Should complete in reasonable time (< 1 second)
      elapsed.total_seconds.should be < 1.0
    end
  end

  describe ".stats" do
    it "returns statistics" do
      stats = EventBroadcaster.stats

      stats["dropped"].should be >= 0
      stats["processed"].should be >= 0
    end
  end

  describe "FeedUpdateEvent" do
    it "serializes to JSON with correct format" do
      event = FeedUpdateEvent.new(1234567890)
      json = event.to_json

      json.should contain("\"type\":\"feed_update\"")
      json.should contain("\"timestamp\":1234567890")
    end

    it "has correct type property" do
      event = FeedUpdateEvent.new(1234567890)
      event.type.should eq("feed_update")
    end

    it "has correct timestamp property" do
      timestamp = 1234567890
      event = FeedUpdateEvent.new(timestamp)
      event.timestamp.should eq(timestamp)
    end
  end

  describe "HeartbeatEvent" do
    it "serializes to JSON with heartbeat type" do
      event = HeartbeatEvent.new
      json = event.to_json

      json.should contain("\"type\":\"heartbeat\"")
    end

    it "has correct type property" do
      event = HeartbeatEvent.new
      event.type.should eq("heartbeat")
    end

    it "includes timestamp" do
      event = HeartbeatEvent.new
      event.timestamp.should be > 0
    end
  end

  describe "integration" do
    it "broadcasts to connected clients" do
      # Start broadcaster
      EventBroadcaster.start

      # Create and register a connection
      ws = HTTP::WebSocket.new("ws://localhost/test")
      SocketManager.instance.register(ws, "192.168.4.1")

      initial_sent = SocketManager.instance.messages_sent

      # Send notification
      EventBroadcaster.notify_feed_update(1234567890)

      # Give time for async processing
      sleep 0.2

      # Verify message was sent
      SocketManager.instance.messages_sent.should be > initial_sent
    end
  end
end
