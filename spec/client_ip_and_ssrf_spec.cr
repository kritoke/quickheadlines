require "./spec_helper"

private def request_from(peer : String, headers = HTTP::Headers.new) : HTTP::Request
  req = HTTP::Request.new("GET", "/", headers)
  req.remote_address = Socket::IPAddress.new(peer, 54321)
  req
end

private def with_env(key : String, value : String?, &)
  old = ENV[key]?
  value ? (ENV[key] = value) : ENV.delete(key)
  yield
ensure
  old ? (ENV[key] = old) : ENV.delete(key)
end

describe "Utils.extract_client_ip" do
  it "uses the TCP peer and ignores a spoofed X-Client-IP" do
    with_env("TRUSTED_PROXY", nil) do
      req = request_from("203.0.113.7", HTTP::Headers{"X-Client-IP" => "1.2.3.4"})
      Utils.extract_client_ip(req).should eq("203.0.113.7")
    end
  end

  it "ignores X-Forwarded-For when TRUSTED_PROXY is not set" do
    with_env("TRUSTED_PROXY", nil) do
      req = request_from("10.0.0.5", HTTP::Headers{"X-Forwarded-For" => "198.51.100.9"})
      Utils.extract_client_ip(req).should eq("10.0.0.5")
    end
  end

  it "uses the right-most X-Forwarded-For entry from a private trusted proxy" do
    with_env("TRUSTED_PROXY", "1") do
      req = request_from("10.0.0.5", HTTP::Headers{"X-Forwarded-For" => "6.6.6.6, 198.51.100.9"})
      Utils.extract_client_ip(req).should eq("198.51.100.9")
    end
  end

  it "ignores X-Forwarded-For from a public peer even when TRUSTED_PROXY is set" do
    with_env("TRUSTED_PROXY", "1") do
      req = request_from("203.0.113.7", HTTP::Headers{"X-Forwarded-For" => "198.51.100.9"})
      Utils.extract_client_ip(req).should eq("203.0.113.7")
    end
  end

  it "returns unknown when there is no peer address" do
    Utils.extract_client_ip(HTTP::Request.new("GET", "/")).should eq("unknown")
  end
end

describe "Utils SSRF guards" do
  non_public = ["127.0.0.1", "10.1.2.3", "172.16.0.1", "192.168.1.1", "169.254.169.254",
                "100.64.0.1", "0.1.2.3", "0.0.0.0", "::1", "fd00::1", "fe80::1", "::ffff:127.0.0.1"]
  non_public.each do |ip|
    it "treats #{ip} as non-public" do
      Utils.non_public_ip?(Socket::IPAddress.new(ip, 0)).should be_true
      Utils.resolves_to_private?(ip).should be_true
    end
  end

  ["8.8.8.8", "1.1.1.1", "2606:4700:4700::1111"].each do |ip|
    it "treats #{ip} as public" do
      Utils.non_public_ip?(Socket::IPAddress.new(ip, 0)).should be_false
      Utils.resolves_to_private?(ip).should be_false
    end
  end

  it "rejects bracketed IPv6 literals" do
    Utils.resolves_to_private?("[::1]").should be_true
  end

  it "rejects hostnames that resolve to loopback" do
    Utils.resolves_to_private?("localhost").should be_true
  end

  it "fails closed when the host does not resolve" do
    Utils.resolves_to_private?("does-not-exist.invalid").should be_true
  end
end
