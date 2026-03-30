require "./application"
require "./websocket"

class ClientIPHandler
  include HTTP::Handler

  def call(ctx : HTTP::Server::Context)
    ip = case addr = ctx.request.remote_address
         when Socket::IPAddress then addr.address
         else
           Utils.parse_ip_address(ctx.request.remote_address.to_s) || ctx.request.remote_address.to_s
         end
    ctx.request.headers["X-Client-IP"] = ip
    call_next(ctx)
  end
end

begin
  config = QuickHeadlines::Application.initial_config
  if config.nil?
    STDERR.puts "[ERROR] Configuration not loaded - check feeds.yml"
    exit 1
  end
  port = config.server_port

  handlers = [] of HTTP::Handler

  handlers << ClientIPHandler.new

  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
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
      # Handle client messages if needed (currently push-only)
    end
  end
  handlers << ws_handler
  STDERR.puts "[WebSocket] Enabled - clients can connect to ws://host/api/ws"

  ATH.run(host: "0.0.0.0", port: port, prepend_handlers: handlers)
rescue ex
  STDERR.puts "[ERROR] Failed to start server: #{ex.message}"
  exit 1
end
