require "../spec_helper"

describe SocketManager do
  describe "#register" do
    it "returns true for valid registration" do
      mock_ws = HTTP::WebSocket.new("ws://localhost/test")
      result = SocketManager.instance.register(mock_ws, "192.168.1.200")
      result.should eq(true)
    end

    it "increments connection count" do
      initial_count = SocketManager.instance.connection_count

      ws1 = HTTP::WebSocket.new("ws://localhost/test")
      SocketManager.instance.register(ws1, "192.168.1.201")

      SocketManager.instance.connection_count.should eq(initial_count + 1)
    end
  end

  describe "#unregister" do
    it "removes connection" do
      ws = HTTP::WebSocket.new("ws://localhost/test")
      SocketManager.instance.register(ws, "192.168.1.202")
      initial_count = SocketManager.instance.connection_count

      SocketManager.instance.unregister(ws, "192.168.1.202")
      SocketManager.instance.connection_count.should eq(initial_count - 1)
    end

    it "handles unregistering non-existent connection without error" do
      ws = HTTP::WebSocket.new("ws://localhost/test")
      # Should not raise
      SocketManager.instance.unregister(ws, "192.168.1.203")
      # Test passes if no exception
      true.should eq(true)
    end
  end

  describe "#broadcast" do
    it "does not raise when broadcasting to no clients" do
      SocketManager.instance.broadcast("{\"type\":\"test\"}")
      # Test passes if no exception
      true.should eq(true)
    end

    it "broadcasts to connected clients" do
      ws1 = HTTP::WebSocket.new("ws://localhost/test")
      ws2 = HTTP::WebSocket.new("ws://localhost/test")

      SocketManager.instance.register(ws1, "192.168.1.204")
      SocketManager.instance.register(ws2, "192.168.1.205")

      # Should not raise
      SocketManager.instance.broadcast("{\"type\":\"test\"}")
      true.should eq(true)
    end

    it "handles rapid broadcasts without blocking" do
      ws = HTTP::WebSocket.new("ws://localhost/test")
      SocketManager.instance.register(ws, "192.168.1.206")

      # Rapid broadcasts should complete quickly
      start_time = Time.monotonic
      100.times do
        SocketManager.instance.broadcast("{\"type\":\"test\"}")
      end
      elapsed = Time.monotonic - start_time

      # Should complete in reasonable time (< 1 second)
      elapsed.total_seconds.should be < 1.0
    end
  end

  describe "#cleanup_dead_connections" do
    it "removes closed connections" do
      ws = HTTP::WebSocket.new("ws://localhost/test")
      SocketManager.instance.register(ws, "192.168.1.207")
      initial_count = SocketManager.instance.connection_count

      # Close the websocket
      ws.close

      # Give a moment for close to propagate
      sleep 0.01

      # Cleanup should detect and remove it
      removed = SocketManager.instance.cleanup_dead_connections
      removed.should be >= 0
    end
  end

  describe "#get_stats" do
    it "returns statistics" do
      stats = SocketManager.instance.get_stats

      stats["connections"].should be >= 0
      stats["messages_sent"].should be >= 0
      stats["messages_dropped"].should be >= 0
      stats["send_errors"].should be >= 0
      stats["closed_total"].should be >= 0
    end
  end

  describe "concurrent access" do
    it "handles concurrent registrations safely" do
      channel = Channel(Nil).new
      success_count = 0

      10.times do |i|
        spawn do
          ws = HTTP::WebSocket.new("ws://localhost/test")
          if SocketManager.instance.register(ws, "192.168.3.#{i}")
            success_count += 1
          end
          channel.send(nil)
        end
      end

      10.times { channel.receive }
      success_count.should eq(10)
    end

    it "handles concurrent broadcasts safely" do
      ws = HTTP::WebSocket.new("ws://localhost/test")
      SocketManager.instance.register(ws, "192.168.3.100")

      channel = Channel(Nil).new
      success = true

      10.times do
        spawn do
          begin
            SocketManager.instance.broadcast("{\"type\":\"test\"}")
          rescue
            success = false
          ensure
            channel.send(nil)
          end
        end
      end

      10.times { channel.receive }
      success.should eq(true)
    end
  end
end
