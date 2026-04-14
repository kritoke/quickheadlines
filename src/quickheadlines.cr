require "./application"
require "./websocket"

require "log"

Log.setup do |builder|
  builder.bind "*", Log::Severity::Info, Log::IOBackend.new
end

module QuickHeadlines
  Log = ::Log.for("quickheadlines")
end

class ClientIPHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    ip = case addr = context.request.remote_address
         when Socket::IPAddress then addr.address
         else
           Utils.parse_ip_address(context.request.remote_address.to_s) || context.request.remote_address.to_s
         end
    context.request.headers["X-Client-IP"] = ip
    call_next(context)
  end
end

begin
  config = QuickHeadlines::Application.initial_config
  if config.nil?
    Log.for("quickheadlines.app").fatal { "[ERROR] Configuration not loaded - check feeds.yml" }
    exit 1
  end
  port = config.server_port

  if bootstrap = QuickHeadlines::Application.bootstrap
    spawn bootstrap.start_background_tasks
    spawn bootstrap.verify_feeds_loaded
  end

  handlers = [] of HTTP::Handler
  handlers << ClientIPHandler.new

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

    ip = case addr = ctx.request.remote_address
         when Socket::IPAddress then addr.address
         else
           Utils.parse_ip_address(ctx.request.remote_address.to_s) || ctx.request.remote_address.to_s
         end

    unless SocketManager.instance.register(ws, ip)
      ws.close
      next
    end

    ws.on_close do
      SocketManager.instance.unregister(ws, ip)
    end

    ws.on_message do |_|
    end
  end
  handlers << ws_handler
  Log.for("quickheadlines.websocket").info { "Enabled - clients can connect to ws://host/api/ws" }

  ATH.run(host: "0.0.0.0", port: port, prepend_handlers: handlers)
rescue ex
  Log.for("quickheadlines.app").fatal(exception: ex) { "Failed to start server" }
  exit 1
end
