require "http"
require "mutex"
require "channel"
require "../constants"

class SocketManager
  @@instance : SocketManager?
  @@mutex = Mutex.new(:unchecked)

  record Connection, websocket : HTTP::WebSocket, ip : String, outgoing : Channel(String), created_at : Time

  @connections : Array(Connection)
  @connections_mutex : Mutex
  @ip_counts : Hash(String, Int32)
  @ip_mutex : Mutex
  @messages_sent : Atomic(Int64)
  @messages_dropped : Atomic(Int64)
  @send_errors : Atomic(Int64)
  @closed_total : Atomic(Int64)
  @last_activity : Hash(HTTP::WebSocket, Time)
  @activity_mutex : Mutex

  def initialize
    @connections = [] of Connection
    @connections_mutex = Mutex.new(:unchecked)
    @ip_counts = {} of String => Int32
    @ip_mutex = Mutex.new(:unchecked)
    @messages_sent = Atomic(Int64).new(0)
    @messages_dropped = Atomic(Int64).new(0)
    @send_errors = Atomic(Int64).new(0)
    @closed_total = Atomic(Int64).new(0)
    @last_activity = {} of HTTP::WebSocket => Time
    @activity_mutex = Mutex.new(:unchecked)
  end

  def self.instance : SocketManager
    @@mutex.synchronize { @@instance ||= SocketManager.new }
  end

  def register(ws : HTTP::WebSocket, ip : String) : Bool
    @connections_mutex.synchronize do
      if @connections.size >= QuickHeadlines::Constants::MAX_CONNECTIONS
        Log.for("quickheadlines.websocket").warn { "Connection rejected: max #{QuickHeadlines::Constants::MAX_CONNECTIONS} connections reached" }
        return false
      end

      count = @ip_counts[ip]?
      if count && count >= QuickHeadlines::Constants::MAX_CONNECTIONS_PER_IP
        Log.for("quickheadlines.websocket").warn { "Connection rejected: max #{QuickHeadlines::Constants::MAX_CONNECTIONS_PER_IP} connections per IP (#{ip})" }
        return false
      end

      registration_state = {ip_counted: false, connection_registered: false}

      begin
        @ip_mutex.synchronize do
          @ip_counts[ip] = (count || 0) + 1
        end
        registration_state = registration_state.merge({ip_counted: true})

        outgoing = Channel(String).new(QuickHeadlines::Constants::CONNECTION_QUEUE_SIZE)
        connection = Connection.new(websocket: ws, ip: ip, outgoing: outgoing, created_at: Time.local)

        @activity_mutex.synchronize do
          @last_activity[ws] = Time.local
        end

        spawn writer_fiber(connection)
        @connections << connection
        registration_state = registration_state.merge({connection_registered: true})
        Log.for("quickheadlines.websocket").info { "Client connected from #{ip}. Total: #{@connections.size}" }
        true
      rescue ex
        if registration_state[:ip_counted] && !registration_state[:connection_registered]
          @ip_mutex.synchronize do
            if c = @ip_counts[ip]?
              @ip_counts[ip] = c - 1
              @ip_counts.delete(ip) if @ip_counts[ip] == 0
            end
          end
        end
        Log.for("quickheadlines.websocket").error(exception: ex) { "Registration failed: #{ex.message}" }
        false
      end
    end
  end

  private def writer_fiber(connection : Connection) : Nil
    loop do
      begin
        message = connection.outgoing.receive?
        break if message.nil?
        connection.websocket.send(message)
        @messages_sent.add(1)

        @activity_mutex.synchronize do
          @last_activity[connection.websocket] = Time.local
        end
      rescue Channel::ClosedError
        break
      rescue IO::TimeoutError
        @send_errors.add(1)
        Log.for("quickheadlines.websocket").warn { "Send timeout for #{connection.ip}" }
        break
      rescue ex
        @send_errors.add(1)
        Log.for("quickheadlines.websocket").error(exception: ex) { "Send error (#{ex.class})" }
        break
      end
    end

    begin
      connection.websocket.close
    rescue IO::Error
      Log.for("quickheadlines.websocket").debug { "WebSocket already closed for cleanup" }
    end
    @closed_total.add(1)
    unregister_connection(connection)
  end

  private def unregister_connection(connection : Connection) : Nil
    @connections_mutex.synchronize do
      @connections.delete(connection)
    end
    decrement_ip_count(connection.ip)
    @activity_mutex.synchronize do
      @last_activity.delete(connection.websocket)
    end
    Log.for("quickheadlines.websocket").info { "Client disconnected from #{connection.ip}. Total: #{connection_count}" }
  end

  private def decrement_ip_count(ip : String) : Nil
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
  end

  def unregister(ws : HTTP::WebSocket, ip : String) : Nil
    connection_to_remove = nil

    @connections_mutex.synchronize do
      idx = @connections.index { |conn| conn.websocket == ws }
      if idx
        connection_to_remove = @connections[idx]
        begin
          connection_to_remove.outgoing.close
        rescue Channel::ClosedError
        end
        @connections.delete_at(idx)
      end
    end

    # Don't call unregister_connection here - the channel close will trigger
    # writer_fiber's Channel::ClosedError which will call unregister_connection.
    # Calling it here would cause double-decrement of IP counts.
  end

  def broadcast(message : String) : Nil
    connections_snapshot = @connections_mutex.synchronize { @connections.dup }

    connections_snapshot.each do |conn|
      begin
        # Use send with timeout to avoid blocking on slow clients
        select
        when conn.outgoing.send(message)
          # Don't increment here - it will be counted in writer_fiber when actually sent
        when timeout(QuickHeadlines::Constants::BROADCAST_TIMEOUT_MS.milliseconds)
          @messages_dropped.add(1)
          Log.for("quickheadlines.websocket").debug { "Dropped message for slow client: #{conn.ip}" }
        end
      rescue Channel::ClosedError
        @messages_dropped.add(1)
      rescue ex : IO::TimeoutError | IO::Error
        @send_errors.add(1)
        Log.for("quickheadlines.websocket").error(exception: ex) { "Broadcast error (#{ex.class})" }
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
    now = Time.local

    @connections_mutex.synchronize do
      @connections.each do |conn|
        begin
          # Check if websocket is closed
          if conn.websocket.closed?
            dead << conn
            next
          end

          # Check if connection is stale (no activity for QuickHeadlines::Constants::STALE_CONNECTION_AGE seconds)
          last_active = @activity_mutex.synchronize { @last_activity[conn.websocket]? }
          if last_active && (now - last_active).total_seconds > QuickHeadlines::Constants::STALE_CONNECTION_AGE
            Log.for("quickheadlines.websocket").debug { "Stale connection detected: #{conn.ip} (inactive for #{((now - last_active).total_seconds).round(0)}s)" }
            dead << conn
          end
        rescue IO::EOFError
          # Normal connection closure, not a dead connection
        rescue IO::Error
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
      rescue Channel::ClosedError | IO::Error
      end
      unregister_connection(conn)
      removed += 1
    end

    Log.for("quickheadlines.websocket").info { "Janitor removed #{removed} dead connections" }
    removed
  end

  def stats
    {
      "connections"      => connection_count,
      "messages_sent"    => messages_sent,
      "messages_dropped" => messages_dropped,
      "send_errors"      => send_errors,
      "closed_total"     => closed_total,
    }
  end

  def shutdown_all_connections : Nil
    snapshot = @connections_mutex.synchronize { @connections.dup }
    snapshot.each do |conn|
      begin
        conn.outgoing.close
      rescue Channel::ClosedError
      end
      begin
        conn.websocket.close
      rescue IO::Error
      end
    end
  end
end
