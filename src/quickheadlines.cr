require "./application"
require "./websocket"
require "./services/clustering_service"
require "./dev_tools/refresh_simulator"

require "http"
require "log"
require "process"
require "signal"
require "time"

Log.setup do |builder|
  builder.bind "*", Log::Severity::Info, Log::IOBackend.new(dispatcher: Log::DirectDispatcher)
end

module QuickHeadlines
  Log = ::Log.for("quickheadlines")
end

class ClientIPHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    context.request.headers["X-Client-IP"] = extract_client_ip(context.request)
    call_next(context)
  end
end

class RequestTimingHandler
  include HTTP::Handler

  SLOW_THRESHOLD_MS = 500.0

  def call(context : HTTP::Server::Context)
    start = Time.monotonic
    call_next(context)
    elapsed = Time.monotonic - start
    ms = elapsed.total_milliseconds
    path = context.request.path
    method = context.request.method
    status = context.response.status_code

    if ms >= SLOW_THRESHOLD_MS
      Log.for("quickheadlines.timing").warn { "#{method} #{path} -> #{status} (#{ms.round(1)}ms)" }
    end
  end
end

SHUTDOWN_LOG = Log.for("quickheadlines.shutdown")

def initiate_shutdown(signal_name : String) : Nil
  return if QuickHeadlines.shutting_down?
  QuickHeadlines.shutting_down = true
  SHUTDOWN_LOG.info { "Received #{signal_name}, initiating graceful shutdown..." }

  # Force exit after 5 seconds if graceful shutdown doesn't complete
  # This handles cases where GC or other operations block shutdown
  spawn do
    begin
      sleep(5.seconds)
      SHUTDOWN_LOG.warn { "Graceful shutdown taking too long, forcing exit" }
      Process.exit(1)
    rescue ex
      SHUTDOWN_LOG.error(exception: ex) { "Force exit fiber failed" }
    end
  end

  SHUTDOWN_LOG.info { "Shutting down WebSocket connections..." }
  EventBroadcaster.shutdown

  # Force close the update channel to unblock any fibers waiting on it
  EventBroadcaster.close_update_channel

  # Clean up rate limiter resources
  QuickHeadlines::RateLimiter.shutdown

  # Gracefully stop actors with network/heavy I/O — shutdown allows in-flight
  # work to complete. FaviconActor gets 10s, ClusteringActor gets 30s.
  spawn do
    FaviconActor.instance.shutdown
  end
  sleep(10.seconds)
  spawn do
    QuickHeadlines::Services::ClusteringActor.instance.shutdown
  end
  sleep(30.seconds)

  SocketManager.instance.shutdown_all_connections
  SHUTDOWN_LOG.info { "Shutdown complete" }
end

Process.on_terminate { initiate_shutdown("SIGTERM") }
Process.on_terminate { initiate_shutdown("SIGINT") }

begin
  config = QuickHeadlines.initial_config
  if config.nil?
    Log.for("quickheadlines.app").fatal { "[ERROR] Configuration not loaded - check feeds.yml" }
    exit 1
  end
  port = config.server_port

  if bootstrap = QuickHeadlines.bootstrap
    # Allow skipping heavy startup background tasks for faster interactive dev/diagnosis.
    # Set environment variable SKIP_STARTUP_TASKS=1 to prevent spawning refresh/clustering
    if ENV["SKIP_STARTUP_TASKS"]?
      Log.for("quickheadlines.app").info { "SKIP_STARTUP_TASKS set; not starting background tasks on startup" }
    else
      spawn do
        begin
          bootstrap.start_background_tasks
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "start_background_tasks fiber crashed" }
        end
      end
      spawn do
        begin
          bootstrap.verify_feeds_loaded
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "verify_feeds_loaded fiber crashed" }
        end
      end
    end
  end

  handlers = [] of HTTP::Handler
  handlers << ClientIPHandler.new
  handlers << RequestTimingHandler.new

  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    origin = ctx.request.headers["Origin"]?
    host = ctx.request.headers["Host"]?

    if !origin
      Log.for("quickheadlines.websocket").warn { "Rejected WebSocket: missing Origin header (APP_ENV=#{ENV["APP_ENV"]? || "unset"})" }
      ws.close
      next
    end

    # If origin is provided, host MUST also be provided for validation
    if origin
      if host.nil? || host.empty?
        Log.for("quickheadlines.websocket").warn { "Rejected WebSocket: Origin header present but Host header missing" }
        ws.close
        next
      end

      origin_host = begin
        uri = URI.parse(origin)
        uri.host.try(&.downcase)
      rescue URI::Error
        # Fallback: strip scheme and extract host, ignoring port
        cleaned = origin.sub(/^https?:\/\//, "").split("/").first.split(":").first
        cleaned unless cleaned.empty?
      end

      host_host = begin
        host.split(":").first
      rescue ArgumentError | NilAssertionError
        host
      end

      if origin_host.nil? || origin_host != host_host
        Log.for("quickheadlines.websocket").warn { "Rejected WebSocket from invalid Origin: #{origin} (expected host: #{host_host})" }
        ws.close
        next
      end
    end

    ip = extract_client_ip(ctx.request)

    unless SocketManager.instance.register(ws, ip)
      ws.close
      next
    end

    EventBroadcaster.add_client(ws)

    ws.on_close do
      SocketManager.instance.unregister(ws, ip)
      EventBroadcaster.remove_client(ws)
    end
  end
  handlers << ws_handler
  Log.for("quickheadlines.websocket").info { "Enabled - clients can connect to ws://host/api/ws" }

  ATH.run(host: "0.0.0.0", port: port, reuse_port: true, prepend_handlers: handlers)
rescue ex
  Log.for("quickheadlines.app").fatal(exception: ex) { "Failed to start server" }
  exit 1
end
