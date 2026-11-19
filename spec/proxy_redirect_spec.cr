require "./spec_helper"
require "athena"
require "../src/controllers/proxy_controller"

# Drives the real redirect loop in ProxyController#proxy_image_fetch against a
# local HTTP server. Production only allows https + allowlisted domains, so
# this subclass swaps in a localhost validator (rejecting any "/blocked" path,
# standing in for an SSRF target) and records each URL it validates, so we
# can assert validation runs on every hop.
private class TestProxyController < QuickHeadlines::Controllers::ProxyController
  getter validated = [] of String

  def self.build : self
    allocate.tap(&.init_for_test)
  end

  def init_for_test : Nil
    @validated = [] of String
  end

  def fetch(url : String) : AHTTP::Response
    proxy_image_fetch(url, 1_000_000_i64)
  end

  private def validate_proxy_url_with_ip(url : String) : {Bool, String?}
    @validated << url
    {!URI.parse(url).path.starts_with?("/blocked"), nil}
  end

  private def create_pinned_client(uri : URI, resolved_ip : String?) : HTTP::Client
    HTTP::Client.new(uri)
  end
end

private def with_image_server(&)
  server = HTTP::Server.new do |ctx|
    path = ctx.request.path
    case path
    when "/img/a.png"
      ctx.response.content_type = "image/png"
      ctx.response.print "PNGDATA"
    when "/img/relative"
      ctx.response.status_code = 302
      ctx.response.headers["Location"] = "a.png" # relative to /img/
    when "/to-blocked"
      ctx.response.status_code = 302
      ctx.response.headers["Location"] = "/blocked/secret.png"
    when %r{^/loop/(\d+)$}
      ctx.response.status_code = 302
      ctx.response.headers["Location"] = "/loop/#{$1.to_i + 1}"
    else
      ctx.response.status_code = 404
    end
  end
  address = server.bind_tcp("127.0.0.1", 0)
  spawn { server.listen }
  Fiber.yield
  begin
    yield "http://127.0.0.1:#{address.port}"
  ensure
    server.close
  end
end

private def status_of(&) : Int32
  yield
  200
rescue ex : AHK::Exception::HTTPException
  ex.status_code
end

describe "ProxyController redirect handling" do
  it "resolves a relative Location against the current URL" do
    with_image_server do |base|
      controller = TestProxyController.build
      response = controller.fetch("#{base}/img/relative")
      response.status.code.should eq(200)
      response.content.should eq("PNGDATA")
      controller.validated.should eq(["#{base}/img/relative", "#{base}/img/a.png"])
    end
  end

  it "validates every hop and blocks a redirect to a disallowed target" do
    with_image_server do |base|
      controller = TestProxyController.build
      status_of { controller.fetch("#{base}/to-blocked") }.should eq(403)
      controller.validated.last.should eq("#{base}/blocked/secret.png")
    end
  end

  it "stops after MAX_PROXY_REDIRECTS hops" do
    with_image_server do |base|
      controller = TestProxyController.build
      status_of { controller.fetch("#{base}/loop/0") }.should eq(502)
      # initial URL + one validation per followed redirect
      max = QuickHeadlines::Controllers::ProxyController::MAX_PROXY_REDIRECTS
      controller.validated.size.should eq(max + 1)
    end
  end
end
