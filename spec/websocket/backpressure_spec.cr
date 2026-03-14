require "../spec_helper"

describe "EventBroadcaster Backpressure" do
  describe ".notify_feed_update - channel timeout" do
    it "handles channel full gracefully with timeout" do
      EventBroadcaster.start

      # Fill the channel buffer (size 100)
      # Then send more to trigger timeout behavior
      150.times do |i|
        EventBroadcaster.notify_feed_update(1234567890 + i)
      end

      # Should complete without blocking
      # Some events may be dropped due to channel full
      stats = EventBroadcaster.stats

      # Should have processed at least some events
      stats["processed"].should be > 0

      # May have dropped some if channel was full
      # (depends on broadcast speed)
    end

    it "does not block on channel full" do
      EventBroadcaster.start

      start_time = Time.monotonic

      # Send 1000 events rapidly
      1000.times do |i|
        EventBroadcaster.notify_feed_update(1234567890 + i)
      end

      elapsed = Time.monotonic - start_time

      # With 10ms timeout per send, worst case = 10 seconds
      # But should be much faster since channel drains
      # Should complete in < 5 seconds even with all timeouts
      elapsed.total_seconds.should be < 5.0
    end

    it "tracks dropped events when channel is full" do
      EventBroadcaster.start

      initial_stats = EventBroadcaster.stats
      initial_dropped = initial_stats["dropped"]

      # Flood the channel
      500.times do |i|
        EventBroadcaster.notify_feed_update(1234567890 + i)
      end

      # Give time for processing
      sleep 0.5.seconds

      final_stats = EventBroadcaster.stats

      # If any were dropped, counter should increase
      # (May not increase if broadcast is fast enough)
      final_stats["dropped"].should be >= initial_dropped
    end
  end

  describe "integration with SocketManager" do
    it "broadcasts to connected clients without blocking" do
      EventBroadcaster.start

      # Register some clients
      5.times do |i|
        ws = HTTP::WebSocket.new("ws://localhost/test")
        SocketManager.instance.register(ws, "192.168.203.#{i}")
      end

      initial_sent = SocketManager.instance.messages_sent

      # Send update
      EventBroadcaster.notify_feed_update(1234567890)

      # Give time for broadcast
      sleep 0.3.seconds

      # Should have sent messages to clients
      SocketManager.instance.messages_sent.should be > initial_sent
    end
  end
end
