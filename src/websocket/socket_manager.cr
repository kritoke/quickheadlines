require "http"
require "mutex"
require "json"
require "channel"

class SocketManager
  @@instance : SocketManager?
  @@mutex = Mutex.new

  @connections : Array(HTTP::WebSocket)
  @connections_mutex : Mutex
  @ip_counts : Hash(String, Int32)
  @ip_mutex : Mutex
  @messages_sent : Atomic(Int64)
  @messages_dropped : Atomic(Int64)
  @send_errors : Atomic(Int64)

  MAX_CONNECTIONS = 1000
  MAX_CONNECTIONS_PER_IP = 10

  def initialize
    @connections = [] of HTTP::WebSocket
    @connections_mutex = Mutex.new
    @ip_counts = {} of String => Int32
    @ip_mutex = Mutex.new
    @messages_sent = Atomic(Int64).new(0)
    @messages_dropped = Atomic(Int64).new(0)
    @send_errors = Atomic(Int64).new(0)
  end

  def self.instance : SocketManager
    @@mutex.synchronize { @@instance ||= SocketManager.new }
  end

  def register(ws : HTTP::WebSocket, ip : String) : Bool
    @connections_mutex.synchronize do
      if @connections.size >= MAX_CONNECTIONS
        STDERR.puts "[SocketManager] Connection rejected: max #{MAX_CONNECTIONS} connections reached"
        return false
      end
    end

    @ip_mutex.synchronize do
      count = @ip_counts[ip]?
      if count && count >= MAX_CONNECTIONS_PER_IP
        STDERR.puts "[SocketManager] Connection rejected: max #{MAX_CONNECTIONS_PER_IP} connections per IP (#{ip})"
        return false
      end
      @ip_counts[ip] = (count || 0) + 1
    end

    @connections_mutex.synchronize do
      @connections << ws
    end
    STDERR.puts "[SocketManager] Client connected from #{ip}. Total: #{connection_count}"
    true
  end

  def unregister(ws : HTTP::WebSocket, ip : String) : Nil
    @connections_mutex.synchronize do
      @connections.delete(ws)
    end
    @ip_mutex.synchronize do
      if count = @ip_counts[ip]?
        @ip_counts[ip] = count - 1
        @ip_counts.delete(ip) if count <= 1
      end
    end
    STDERR.puts "[SocketManager] Client disconnected from #{ip}. Total: #{connection_count}"
  end

  def broadcast(message : String) : Nil
    connections_copy = @connections_mutex.synchronize { @connections.dup }
    dead = [] of HTTP::WebSocket

    connections_copy.each do |ws|
      begin
        ws.send(message)
        @messages_sent.add(1)
      rescue ex
        @send_errors.add(1)
        STDERR.puts "[SocketManager] Send error (#{ex.class}): #{ex.message}"
        dead << ws
      end
    end

    unless dead.empty?
      @connections_mutex.synchronize do
        dead.each { |ws| @connections.delete(ws) }
      end
      dead.each do |ws|
        ip = "unknown"
        @ip_mutex.synchronize do
          if count = @ip_counts[ip]?
            @ip_counts[ip] = count - 1
            @ip_counts.delete(ip) if count <= 1
          end
        end
      end
    end
  end

  def connection_count : Int32
    @connections_mutex.synchronize { @connections.size }
  end

  def messages_sent : Int64
    @messages_sent.get
  end

  def messages_dropped : Int64
    @messages_dropped.get
  end

  def send_errors : Int64
    @send_errors.get
  end

  def cleanup_dead_connections : Int32
    dead = @connections_mutex.synchronize do
      @connections.select { |ws| !ws.closed? }
    end
    return 0 if dead.empty?

    removed = 0
    dead.each do |ws|
      begin
        ws.close
      rescue
      end
      @connections_mutex.synchronize do
        @connections.delete(ws)
        removed += 1
      end
    end
    STDERR.puts "[SocketManager] Janitor removed #{removed} dead connections"
    removed
  end
end
