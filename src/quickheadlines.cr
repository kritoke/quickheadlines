require "./application"
require "./websocket"

begin
  config_result = load_config_with_validation("feeds.yml")
  port = 8080
  use_websocket = false

  if config_result.success
    cfg = config_result.config.as(Config)
    port = cfg.server_port
    use_websocket = cfg.use_websocket?
  else
    STDERR.puts "[WARN] Could not load feeds.yml to determine server_port; defaulting to #{port}"
  end

  handlers = [] of HTTP::Handler

  if use_websocket
    ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
      ip = ctx.request.remote_address.to_s.split(":").first

      unless SocketManager.instance.register(ws, ip)
        ws.close
        next
      end

      ws.on_close do
        SocketManager.instance.unregister(ws, ip)
      end

      ws.on_message do |msg|
        # Handle client messages if needed (currently push-only)
      end
    end
    handlers << ws_handler
    STDERR.puts "[WebSocket] Enabled - clients can connect to ws://host/api/ws"
  else
    STDERR.puts "[WebSocket] Disabled (use_websocket: true in feeds.yml to enable)"
  end

  ATH.run(port: port, prepend_handlers: handlers)
rescue ex
  STDERR.puts "[ERROR] Failed to start server: #{ex.message}"
  exit 1
end
