require "http"
require "mutex"
require "channel"
require "../constants"

class SocketManager
  # NOTE: Uses :unchecked mutex to avoid Boehm GC mutex initialization
  # deadlocks on FreeBSD. See AGENTS.md for details.
  @@instance : SocketManager?
  @@mutex = Mutex.new(:unchecked)

  record Connection, websocket : HTTP::WebSocket, ip : String, outgoing : Channel(String), created_at : Time

  @connections : Array(Connection)
  @mutex : Mutex
  @ip_counts : Hash(String, Int32)
  @messages_sent : Atomic(Int64)
  @messages_dropped : Atomic(Int64)
  @send_errors : Atomic(Int64)
  @closed_total : Atomic(Int64)
  @last_activity : Hash(HTTP::WebSocket, Time)

  def initialize
    @connections = [] of Connection
    @mutex = Mutex.new(:unchecked)
    @ip_counts = {} of String => Int32
    @messages_sent = Atomic(Int64).new(0)
    @messages_dropped = Atomic(Int64).new(0)
    @send_errors = Atomic(Int64).new(0)
    @closed_total = Atomic(Int64).new(0)
    @last_activity = {} of HTTP::WebSocket => Time
  end

  def self.instance : SocketManager
    @@mutex.synchronize { @@instance ||= SocketManager.new }
  end

  def register(ws : HTTP::WebSocket, ip : String) : Bool
    @mutex.synchronize do
      purge_closed_connections

      if @connections.size >= QuickHeadlines::Constants::MAX_CONNECTIONS
        Log.for("quickheadlines.websocket").warn { "Connection rejected: max #{QuickHeadlines::Constants::MAX_CONNECTIONS} connections reached" }
        return false
      end

      count = @ip_counts[ip]?
      if count && count >= QuickHeadlines::Constants::MAX_CONNECTIONS_PER_IP
        Log.for("quickheadlines.websocket").warn { "Connection rejected: max #{QuickHeadlines::Constants::MAX_CONNECTIONS_PER_IP} connections per IP (#{ip})" }
        return false
      end

      ip_counted = false

      begin
        @ip_counts[ip] = (count || 0) + 1
        ip_counted = true

        outgoing = Channel(String).new(QuickHeadlines::Constants::CONNECTION_QUEUE_SIZE)
        connection = Connection.new(websocket: ws, ip: ip, outgoing: outgoing, created_at: Time.utc)

        @last_activity[ws] = Time.utc

        spawn writer_fiber(connection)
        @connections << connection
        Log.for("quickheadlines.websocket").info { "Client connected from #{ip}. Total: #{@connections.size}" }
        true
      rescue ex
        if ip_counted
          if c = @ip_counts[ip]?
            @ip_counts[ip] = c - 1
            @ip_counts.delete(ip) if @ip_counts[ip] == 0
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

        @mutex.synchronize do
          @last_activity[connection.websocket] = Time.utc
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
    # NOTE: IP count decrement is handled by unregister() to prevent double-decrement.
    # This method is called by writer_fiber when the channel is closed.
    # The connection should already be removed from @connections by unregister(),
    # but we check and remove it anyway for safety.
    @mutex.synchronize do
      was_present = @connections.includes?(connection)
      @connections.delete(connection)
      @last_activity.delete(connection.websocket)
      # Only decrement IP count if this is called directly (e.g., by janitor cleanup)
      # NOT when called from writer_fiber after unregister() already decremented
      if was_present
        decrement_ip_count_locked(connection.ip)
        Log.for("quickheadlines.websocket").warn { "unregister_connection: connection was still in array, decremented IP count" }
      end
    end
    Log.for("quickheadlines.websocket").info { "Client disconnected from #{connection.ip}. Total: #{connection_count}" }
  end

  # Must be called inside @mutex.synchronize
  private def decrement_ip_count_locked(ip : String) : Nil
    if count = @ip_counts[ip]?
      new_count = count - 1
      if new_count < 0
        # BUG DETECTION: IP count went negative, indicating a double-decrement
        # This should never happen - either unregister or writer_fiber should
        # handle the decrement, not both.
        Log.for("quickheadlines.websocket").error { "IP count for #{ip} went negative (#{count} -> #{new_count}). Potential double-decrement detected." }
        @ip_counts[ip] = 0
      elsif new_count == 0
        @ip_counts.delete(ip)
        Log.for("quickheadlines.websocket").debug { "IP count for #{ip} reached 0, removed from tracking" }
      else
        @ip_counts[ip] = new_count
      end
    else
      Log.for("quickheadlines.websocket").warn { "decrement_ip_count called for unknown IP: #{ip} - connection already cleaned up" }
    end
  end

  # Thread-safe decrement for calls outside mutex
  private def decrement_ip_count(ip : String) : Nil
    @mutex.synchronize { decrement_ip_count_locked(ip) }
  end

  def unregister(ws : HTTP::WebSocket, ip : String) : Nil
    connection_to_cleanup = nil
    
    @mutex.synchronize do
      idx = @connections.index { |conn| conn.websocket == ws }
      return unless idx

      connection_to_cleanup = @connections[idx]
      @connections.delete_at(idx)
      @last_activity.delete(connection_to_cleanup.websocket)
      # Decrement IP count here within the mutex to ensure single decrement
      decrement_ip_count_locked(connection_to_cleanup.ip)
    end
    
    # Close channel OUTSIDE the mutex to avoid holding mutex while doing I/O
    if connection_to_cleanup
      begin
        connection_to_cleanup.outgoing.close
      rescue Channel::ClosedError
        # Channel already closed, safe to ignore
      end
    end
  end

  private def purge_closed_connections : Nil
    # Must be called inside @mutex.synchronize
    @connections.reject! do |conn|
      dead = begin
        conn.websocket.closed?
      rescue
        true
      end

      if dead
        decrement_ip_count_locked(conn.ip)
        begin
          conn.outgoing.close
        rescue Channel::ClosedError
        end
      end

      dead
    end
  end

  def broadcast(message : String) : Nil
    connections_snapshot = @mutex.synchronize { @connections.dup }

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
    @mutex.synchronize { @connections.size }
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
    now = Time.utc

    @mutex.synchronize do
      @connections.each do |conn|
        begin
          # Check if websocket is closed
          if conn.websocket.closed?
            dead << conn
            next
          end

          # Check if connection is stale (no activity for QuickHeadlines::Constants::STALE_CONNECTION_AGE seconds)
          last_active = @last_activity[conn.websocket]?
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
    snapshot = @mutex.synchronize { @connections.dup }
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
