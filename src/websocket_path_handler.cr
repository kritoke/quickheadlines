require "http/server"

# Routes WebSocket upgrades only for one exact path; everything else falls
# through to the next handler untouched.
class WebSocketPathHandler
  include HTTP::Handler

  def initialize(@path : String, @inner : HTTP::WebSocketHandler)
  end

  def call(context : HTTP::Server::Context)
    if context.request.path == @path
      @inner.next = self.next
      @inner.call(context)
    else
      call_next(context)
    end
  end
end
