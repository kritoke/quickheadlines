require "./application"
require "./websocket"

module QuickHeadlines
  TRUSTED_PROXIES = {"127.0.0.1", "::1", "10.", "172.16.", "192.168."}

  def self.extract_client_ip(ctx : HTTP::Server::Context) : String
    remote = ctx.request.remote_address.to_s.split(":").first

    if xff = ctx.request.headers.get?("X-Forwarded-For")
      if TRUSTED_PROXIES.any? { |proxy| remote.starts_with?(proxy) }
        return xff.first.split(",").first.strip
      end
    end

    remote
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

  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    ip = QuickHeadlines.extract_client_ip(ctx)

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
