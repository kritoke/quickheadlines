require "spec"
require "http/server"
require "http/web_socket"
require "../src/websocket_path_handler"

private def with_ws_server(&)
  ws = HTTP::WebSocketHandler.new { |socket, _ctx| socket.send("hello") }
  handlers = [WebSocketPathHandler.new("/api/ws", ws)] of HTTP::Handler
  server = HTTP::Server.new(handlers, &.response.print("fallthrough"))
  address = server.bind_tcp("127.0.0.1", 0)
  spawn { server.listen }
  Fiber.yield
  begin
    yield address.port
  ensure
    server.close
  end
end

private def upgrade_headers : HTTP::Headers
  HTTP::Headers{
    "Upgrade"               => "websocket",
    "Connection"            => "Upgrade",
    "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
    "Sec-WebSocket-Version" => "13",
  }
end

describe WebSocketPathHandler do
  it "upgrades a WebSocket request on the configured path" do
    with_ws_server do |port|
      response = HTTP::Client.new("127.0.0.1", port).get("/api/ws", headers: upgrade_headers)
      response.status_code.should eq(101)
    end
  end

  it "does not upgrade on any other path" do
    with_ws_server do |port|
      ["/", "/api/ws/", "/api/wsx", "/other"].each do |path|
        response = HTTP::Client.new("127.0.0.1", port).get(path, headers: upgrade_headers)
        response.status_code.should eq(200)
        response.body.should eq("fallthrough")
      end
    end
  end
end
