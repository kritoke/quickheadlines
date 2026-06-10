require "http"
require "channel"
require "../constants"
require "../infrastructure/actor"
require "../services/fiber_tracker"

# SocketManager — Actor-based WebSocket connection lifecycle manager.
#
# All connection state (@connections, @ip_counts, @last_activity) is owned
# and mutated exclusively by the actor's message loop. No mutexes needed.
#
# Writer fibers are per-connection IO workers that report back via messages.
# This makes double-decrement races impossible by construction.
#
class SocketManager < Actor
  # =========================================================================
  # Connection record — immutable, owned by the actor
  # =========================================================================
  class Connection
    getter websocket : HTTP::WebSocket
    getter ip : String
    getter outgoing : Channel(String)
    getter created_at : Time

    def initialize(@websocket, @ip, @outgoing, @created_at)
    end
  end

  # =========================================================================
  # Messages
  # =========================================================================

  # === Call messages (request-reply) ===
  # No-arg form: def_call name : ReturnType
  # With-args form: def_call name(args), ReturnType
  def_call get_connection_count, Int32
  def_call get_stats, Hash(String, Int64)
  def_call cleanup_dead, Int32
  def_call register_connection(ws : HTTP::WebSocket, ip : String), Bool

  # Cast messages (fire-and-forget)
  def_cast unregister_connection(ws : HTTP::WebSocket, ip : String)
  def_cast broadcast_message(message : String)
  def_cast connection_closed(ws : HTTP::WebSocket)
  def_cast connection_send_error(ws : HTTP::WebSocket, error_class : String)
  def_cast connection_activity(ws : HTTP::WebSocket)
  def_cast shutdown_all

  # =========================================================================
  # Actor state — only accessed inside dispatch handlers
  # =========================================================================

  def initialize(@name : String = "SocketManager")
    super(@name, mailbox_size: 100)
    @connections = [] of Connection
    @ip_counts = {} of String => Int32
    @last_activity = {} of HTTP::WebSocket => Time
    @messages_sent = 0_i64
    @messages_dropped = 0_i64
    @send_errors = 0_i64
    @closed_total = 0_i64
  end

  # Singleton access
  @@instance : SocketManager?
  @@instance_mutex = Mutex.new

  def self.instance : SocketManager
    @@instance_mutex.synchronize do
      @@instance ||= SocketManager.new.tap(&.start)
    end
  end

  # Convenience aliases for backward compatibility
  def broadcast(message : String) : Nil
    broadcast_message(message)
  end

  def shutdown_all_connections : Nil
    shutdown_all
  end

  def cleanup_dead_connections : Int32
    cleanup_dead
  end

  def connection_count : Int32
    get_connection_count
  end

  def register(ws : HTTP::WebSocket, ip : String) : Bool
    register_connection(ws, ip)
  end

  def unregister(ws : HTTP::WebSocket, ip : String) : Nil
    unregister_connection(ws, ip)
  end

  # Override Actor#stats to return SocketManager-specific stats
  def connection_stats : Hash(String, Int64)
    get_stats
  end

  # =========================================================================
  # Dispatch — routes messages to handlers
  # =========================================================================

  def dispatch(message : Message) : Nil
    case message
    when CastUnregisterConnection then handle_unregister_connection(message.ws, message.ip)
    when CastBroadcastMessage     then handle_broadcast_message(message.message)
    when CastConnectionClosed     then handle_connection_closed(message.ws)
    when CastConnectionSendError  then handle_connection_send_error(message.ws, message.error_class)
    when CastConnectionActivity   then handle_connection_activity(message.ws)
    when CastShutdownAll          then handle_shutdown_all
    when CallRegisterConnection   then message.deliver_reply_json(handle_register_connection(message.ws, message.ip).to_json)
    when CallGetConnectionCount   then message.deliver_reply_json(handle_get_connection_count.to_json)
    when CallGetStats             then message.deliver_reply_json(handle_get_stats.to_json)
    when CallCleanupDead          then message.deliver_reply_json(handle_cleanup_dead.to_json)
    else                               raise "Unknown message: #{message.class.name}"
    end
  end

  # =========================================================================
  # Handlers — all state mutation happens here, single-threaded
  # =========================================================================

  private def handle_register_connection(ws : HTTP::WebSocket, ip : String) : Bool
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

    @ip_counts[ip] = (count || 0) + 1

    outgoing = Channel(String).new(QuickHeadlines::Constants::CONNECTION_QUEUE_SIZE)
    connection = Connection.new(websocket: ws, ip: ip, outgoing: outgoing, created_at: Time.utc)
    @last_activity[ws] = Time.utc
    @connections << connection

    # Spawn writer fiber — it reports back via messages, not direct mutation
    spawn_writer_fiber(connection)

    Log.for("quickheadlines.websocket").info { "Client connected from #{ip}. Total: #{@connections.size}" }
    true
  rescue ex
    # Roll back IP count on failure
    if c = @ip_counts[ip]?
      @ip_counts[ip] = c - 1
      @ip_counts.delete(ip) if @ip_counts[ip] == 0
    end
    Log.for("quickheadlines.websocket").error(exception: ex) { "Registration failed: #{ex.message}" }
    false
  end

  private def handle_unregister_connection(ws : HTTP::WebSocket, ip : String) : Nil
    idx = @connections.index { |conn| conn.websocket == ws }
    return unless idx

    conn = @connections[idx]
    @connections.delete_at(idx)
    @last_activity.delete(ws)
    decrement_ip_count(conn.ip)

    begin
      conn.outgoing.close
    rescue Channel::ClosedError
    end

    Log.for("quickheadlines.websocket").info { "Client disconnected from #{conn.ip}. Total: #{@connections.size}" }
  end

  private def handle_broadcast_message(message : String) : Nil
    @connections.each do |conn|
      begin
        select
        when conn.outgoing.send(message)
          # Will be counted by writer fiber on actual send
        when timeout(QuickHeadlines::Constants::BROADCAST_TIMEOUT_MS.milliseconds)
          @messages_dropped += 1
          Log.for("quickheadlines.websocket").debug { "Dropped message for slow client: #{conn.ip}" }
        end
      rescue Channel::ClosedError
        @messages_dropped += 1
      rescue ex : IO::TimeoutError | IO::Error
        @send_errors += 1
        Log.for("quickheadlines.websocket").error(exception: ex) { "Broadcast error (#{ex.class})" }
      end
    end
  end

  private def handle_connection_closed(ws : HTTP::WebSocket) : Nil
    idx = @connections.index { |conn| conn.websocket == ws }
    return unless idx

    conn = @connections[idx]
    @connections.delete_at(idx)
    @last_activity.delete(ws)
    decrement_ip_count(conn.ip)
    @closed_total += 1

    begin
      conn.outgoing.close
    rescue Channel::ClosedError
    end

    Log.for("quickheadlines.websocket").debug { "Connection closed by writer fiber: #{conn.ip}. Total: #{@connections.size}" }
  end

  private def handle_connection_send_error(ws : HTTP::WebSocket, error_class : String) : Nil
    @send_errors += 1
    Log.for("quickheadlines.websocket").warn { "Send error (#{error_class}) for connection" }
    # Connection will be cleaned up when it closes
  end

  private def handle_connection_activity(ws : HTTP::WebSocket) : Nil
    @last_activity[ws] = Time.utc
  end

  private def handle_shutdown_all : Nil
    @connections.each do |conn|
      begin
        conn.outgoing.close
      rescue Channel::ClosedError
      end
      begin
        conn.websocket.close
      rescue IO::Error
      end
    end
    @connections.clear
    @ip_counts.clear
    @last_activity.clear
    Log.for("quickheadlines.websocket").info { "All connections shut down" }
  end

  private def handle_cleanup_dead : Int32
    now = Time.utc
    removed = 0

    @connections.reject! do |conn|
      dead = begin
        conn.websocket.closed?
      rescue IO::Error
        true
      end

      unless dead
        last_active = @last_activity[conn.websocket]?
        if last_active && (now - last_active).total_seconds > QuickHeadlines::Constants::STALE_CONNECTION_AGE
          Log.for("quickheadlines.websocket").debug { "Stale connection detected: #{conn.ip}" }
          dead = true
        end
      end

      if dead
        decrement_ip_count(conn.ip)
        @last_activity.delete(conn.websocket)
        begin
          conn.outgoing.close
        rescue Channel::ClosedError
        end
        removed += 1
      end

      dead
    end

    Log.for("quickheadlines.websocket").info { "Janitor removed #{removed} dead connections" } if removed > 0
    removed
  end

  private def handle_get_connection_count : Int32
    @connections.size
  end

  private def handle_get_stats : Hash(String, Int64)
    {
      "connections"      => @connections.size.to_i64,
      "messages_sent"    => @messages_sent,
      "messages_dropped" => @messages_dropped,
      "send_errors"      => @send_errors,
      "closed_total"     => @closed_total,
    }
  end

  # =========================================================================
  # Helpers
  # =========================================================================

  private def decrement_ip_count(ip : String) : Nil
    if count = @ip_counts[ip]?
      new_count = count - 1
      if new_count <= 0
        @ip_counts.delete(ip)
      else
        @ip_counts[ip] = new_count
      end
    end
  end

  private def purge_closed_connections : Nil
    @connections.reject! do |conn|
      dead = begin
        conn.websocket.closed?
      rescue IO::Error
        true
      end

      if dead
        decrement_ip_count(conn.ip)
        @last_activity.delete(conn.websocket)
        begin
          conn.outgoing.close
        rescue Channel::ClosedError
        end
      end

      dead
    end
  end

  # Writer fiber — per-connection IO worker.
  # Reports back to actor via messages. Does NOT mutate actor state directly.
  private def spawn_writer_fiber(connection : Connection) : Nil
    RefreshLoop::FiberTracker.tracked_spawn("ws-writer-#{connection.ip}") do
      loop do
        begin
          message = connection.outgoing.receive?
          break if message.nil?

          connection.websocket.send(message)
          @messages_sent += 1
          connection_activity(connection.websocket)
        rescue Channel::ClosedError
          break
        rescue IO::TimeoutError
          connection_send_error(connection.websocket, "IO::TimeoutError")
          break
        rescue ex
          connection_send_error(connection.websocket, ex.class.name)
          break
        end
      end

      begin
        connection.websocket.close
      rescue IO::Error
      end

      connection_closed(connection.websocket)
    end
  end
end
