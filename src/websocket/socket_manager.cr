require "http"
require "mutex"
require "channel"

class SocketManager
  @@instance : SocketManager?
  @@mutex = Mutex.new

  record Connection, websocket : HTTP::WebSocket, ip : String, outgoing : Channel(String), created_at : Time

  @connections : Array(Connection)
  @connections_mutex : Mutex
  @ip_counts : Hash(String, Int32)
  @ip_mutex : Mutex
  @messages_sent : Atomic(Int64)
  @messages_dropped : Atomic(Int64)
  @send_errors : Atomic(Int64)
  @closed_total : Atomic(Int64)

  MAX_CONNECTIONS = 1000
  MAX_CONNECTIONS_PER_IP = 10
  CONNECTION_QUEUE_SIZE = 100

  def initialize
    @connections = [] of Connection
    @connections_mutex = Mutex.new
    @ip_counts = {} of String => Int32
    @ip_mutex = Mutex.new
    @messages_sent = Atomic(Int64).new(0)
    @messages_dropped = Atomic(Int64).new(0)
    @send_errors = Atomic(Int64).new(0)
    @closed_total = Atomic(Int64).new(0)
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

    outgoing = Channel(String).new(CONNECTION_QUEUE_SIZE)
    connection = Connection.new(websocket: ws, ip: ip, outgoing: outgoing, created_at: Time.local)
    spawn writer_fiber(connection)

    @connections_mutex.synchronize do
      @connections << connection
    end
    STDERR.puts "[SocketManager] Client connected from #{ip}. Total: #{connection_count}"
    true
  end

  private def writer_fiber(connection : Connection) : Nil
    loop do
      begin
        message = connection.outgoing.receive?
        break if message.nil?
        connection.websocket.send(message)
        @messages_sent.add(1)
      rescue Channel::ClosedError
        break
      rescue ex : IO::TimeoutError
        @send_errors.add(1)
        STDERR.puts "[SocketManager] Send timeout for #{connection.ip}"
        break
      rescue ex
        @send_errors.add(1)
        STDERR.puts "[SocketManager] Send error (#{ex.class}): #{ex.message}"
        break
      end
    end

    begin
      connection.websocket.close
    rescue
    end
    @closed_total.add(1)
    unregister_connection(connection)
  end

  private def unregister_connection(connection : Connection) : Nil
    @connections_mutex.synchronize do
      @connections.delete(connection)
    end
    @ip_mutex.synchronize do
      ip = connection.ip
      if count = @ip_counts[ip]?
        new_count = count - 1
        if new_count <= 0
          @ip_counts.delete(ip)
        else
          @ip_counts[ip] = new_count
        end
      end
    end
    STDERR.puts "[SocketManager] Client disconnected from #{connection.ip}. Total: #{connection_count}"
  end

  def unregister(ws : HTTP::WebSocket, ip : String) : Nil
    connection_to_remove = nil

    @connections_mutex.synchronize do
      idx = @connections.index { |conn| conn.websocket == ws }
      if idx
        connection_to_remove = @connections[idx]
        connection_to_remove.outgoing.close rescue nil
        @connections.delete_at(idx)
      end
    end

    return if connection_to_remove.nil?
    @ip_mutex.synchronize do
      if count = @ip_counts[ip]?
        new_count = count - 1
        if new_count <= 0
          @ip_counts.delete(ip)
        else
          @ip_counts[ip] = new_count
        end
      end
    end
    STDERR.puts "[SocketManager] Client disconnected from #{ip}. Total: #{connection_count}"
  end

  def broadcast(message : String) : Nil
    connections_snapshot = @connections_mutex.synchronize { @connections.dup }

    connections_snapshot.each do |conn|
      begin
        conn.outgoing.send(message)
        @messages_sent.add(1)
      rescue Channel::ClosedError
        @messages_dropped.add(1)
      rescue ex
        @send_errors.add(1)
        STDERR.puts "[SocketManager] Broadcast error (#{ex.class}): #{ex.message}"
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

  def closed_total : Int64
    @closed_total.get
  end

  def cleanup_dead_connections : Int32
    dead = [] of Connection

    @connections_mutex.synchronize do
      @connections.each do |conn|
        begin
          if conn.websocket.closed?
            dead << conn
          end
        rescue
          dead << conn
        end
      end
    end

    return 0 if dead.empty?

    removed = 0
    dead.each do |conn|
      begin
        conn.outgoing.close
        conn.websocket.close
      rescue
      end

      @connections_mutex.synchronize do
        @connections.delete(conn)
        removed += 1
      end

      @ip_mutex.synchronize do
        ip = conn.ip
        if count = @ip_counts[ip]?
          new_count = count - 1
          if new_count <= 0
            @ip_counts.delete(ip)
          else
            @ip_counts[ip] = new_count
          end
        end
      end
    end

    STDERR.puts "[SocketManager] Janitor removed #{removed} dead connections"
    removed
  end

  def get_stats
    {
      "connections" => connection_count,
      "messages_sent" => messages_sent,
      "messages_dropped" => messages_dropped,
      "send_errors" => send_errors,
      "closed_total" => closed_total
    }
  end
end
