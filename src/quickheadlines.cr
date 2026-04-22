require "./application"
require "./websocket"

require "http"
require "log"
require "time"

Log.setup do |builder|
  builder.bind "*", Log::Severity::Info, Log::IOBackend.new
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
      spawn bootstrap.start_background_tasks
      spawn bootstrap.verify_feeds_loaded
    end
  end

  handlers = [] of HTTP::Handler
  handlers << ClientIPHandler.new
  handlers << RequestTimingHandler.new

  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    origin = ctx.request.headers["Origin"]?
    host = ctx.request.headers["Host"]?

    if origin && host
      origin_host = origin.sub(/^https?:\/\//, "").rstrip("/")
      unless origin_host == host
        Log.for("quickheadlines.websocket").warn { "Rejected WebSocket from invalid Origin: #{origin} (expected: #{host})" }
        ws.close
        next
      end
    end

    ip = extract_client_ip(ctx.request)

    unless SocketManager.instance.register(ws, ip)
      ws.close
      next
    end

    ws.on_close do
      SocketManager.instance.unregister(ws, ip)
    end
  end
  handlers << ws_handler
  Log.for("quickheadlines.websocket").info { "Enabled - clients can connect to ws://host/api/ws" }

  ATH.run(host: "0.0.0.0", port: port, reuse_port: true, prepend_handlers: handlers)
rescue ex
  Log.for("quickheadlines.app").fatal(exception: ex) { "Failed to start server" }
  exit 1
end
