require "./application"
require "./websocket"
require "./services/clustering_service"
require "./dev_tools/refresh_simulator"

require "http"
require "log"
require "process"
require "signal"
require "time"
require "./services/fiber_tracker"

Log.setup do |builder|
  builder.bind "*", Log::Severity::Info, Log::IOBackend.new(dispatcher: Log::DirectDispatcher)
end

module QuickHeadlines
  Log = ::Log.for("quickheadlines")
end

class ClientIPHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    context.request.headers["X-Client-IP"] = ::Utils.extract_client_ip(context.request)
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
  RefreshLoop::FiberTracker.tracked_spawn do
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
  RefreshLoop::FiberTracker.tracked_spawn do
    FaviconActor.instance.shutdown
  end
  sleep(10.seconds)
  RefreshLoop::FiberTracker.tracked_spawn do
    QuickHeadlines::Services::ClusteringActor.instance.shutdown
  end
  sleep(30.seconds)

  SocketManager.instance.shutdown_all_connections
  SHUTDOWN_LOG.info { "Shutdown complete" }
end

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
      RefreshLoop::FiberTracker.tracked_spawn do
        begin
          bootstrap.start_background_tasks
        rescue ex
          Log.for("quickheadlines.app").error(exception: ex) { "start_background_tasks fiber crashed" }
        end
      end
      RefreshLoop::FiberTracker.tracked_spawn do
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

    ip = ::Utils.extract_client_ip(ctx.request)

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

  # Construct the server instance directly (instead of `ATH.run`)
  # so we can call `stop` on it from our signal handler. `ATH.run`
  # is a thin wrapper that creates a server and discards the
  # reference, which means there's no way to gracefully stop
  # the listener from outside.
  server = ATH::Server.new(port, "0.0.0.0", true, nil, handlers)

  # Re-trap SIGINT/SIGTERM/SIGHUP AFTER Athena's internal
  # `Process.on_terminate { self.stop }` (called inside
  # `Server#start`) has registered. Without this re-trap, Athena's
  # handler would replace ours and `initiate_shutdown` would
  # never run, leaving the process alive after SIGINT.
  # The original shutdown design registered `Process.on_terminate`
  # at the top of the file (line 93) but that handler was silently
  # replaced by Athena's `Process.on_terminate { self.stop }` inside
  # `Server#start` (lib/athena/src/athena.cr:228), so the graceful
  # shutdown path was never running — only the server listener
  # closed, leaving the process alive until the 5s force-exit timer
  # eventually fired.
  #
  # We now re-register our handler in a spawned fiber that runs
  # 0.5s after `server.start` is called. By that point Athena has
  # registered its own handler; our `Process.on_terminate` call
  # overrides it. The user block does both `initiate_shutdown`
  # (the graceful path) and `server.stop` (closes the listener).
  # `server.stop` is also called by Athena's handler, but calling
  # it twice is idempotent (the server checks `closed?` first).
  spawn do
    sleep 0.5.seconds
    Process.on_terminate do |_reason|
      initiate_shutdown("signal")
      begin
        server.stop
      rescue ex
        SHUTDOWN_LOG.warn(exception: ex) { "server.stop failed during shutdown" }
      end
    end
  end

  server.start
rescue ex
  Log.for("quickheadlines.app").fatal(exception: ex) { "Failed to start server" }
  exit 1
end
