require "./application"
require "./websocket"

begin
  port = QuickHeadlines::Application.initial_config.server_port

  handlers = [] of HTTP::Handler

  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    ip = ctx.request.remote_address.to_s.split(":").first

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
