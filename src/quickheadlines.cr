require "./application"
require "./websocket"

begin
  config = QuickHeadlines::Application.initial_config
  if config.nil?
    STDERR.puts "[ERROR] Configuration not loaded - check feeds.yml"
    exit 1
  end
  port = config.server_port

  handlers = [] of HTTP::Handler

  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    ip = case addr = ctx.request.remote_address
         when Socket::IPAddress then addr.address
         else
           addr_str = ctx.request.remote_address.to_s
           # Handle IPv6 format [::1]:port or ::1:port
           if addr_str.starts_with?("[") && addr_str.includes?("]:")
             addr_str.split("]:").first.lchop("[")
           elsif addr_str.count(':') > 1 # IPv6 without brackets
             # Remove port: find last colon that's followed by digits only
             if (port_match = addr_str.match(/:(\d+)$/))
               addr_str[0...-port_match[0].size]
             else
               addr_str
             end
           else
             addr_str.split(":").first
           end
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
