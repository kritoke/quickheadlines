require "spec"
require "../src/utils"
require "../src/config"

describe "Utils" do
  describe "validate_feed_url" do
    it "returns true for valid https URL" do
      Utils.validate_feed_url("https://example.com/feed.xml").should be_true
    end

    it "returns true for valid http URL" do
      Utils.validate_feed_url("http://example.com/feed.xml").should be_true
    end

    it "returns false for empty URL" do
      Utils.validate_feed_url("").should be_false
    end

    it "returns false for whitespace-only URL" do
      Utils.validate_feed_url("   ").should be_false
    end

    it "returns false for ftp URL" do
      Utils.validate_feed_url("ftp://example.com/feed.xml").should be_false
    end

    it "returns false for file URL" do
      Utils.validate_feed_url("file:///path/to/file").should be_false
    end

    it "returns false for URL without scheme" do
      Utils.validate_feed_url("example.com/feed.xml").should be_false
    end

    it "returns false for malformed URL" do
      Utils.validate_feed_url("not a valid url").should be_false
    end

    it "returns true for URL with trailing whitespace" do
      Utils.validate_feed_url("https://example.com/feed.xml  ").should be_true
    end

    it "returns false for URL with no host" do
      Utils.validate_feed_url("https://").should be_false
    end
  end

  describe "parse_ip_address" do
    it "returns IP for IPv4 address with port" do
      Utils.parse_ip_address("192.168.1.1:8080").should eq("192.168.1.1")
    end

    it "returns IP for plain IPv4 address" do
      Utils.parse_ip_address("192.168.1.1").should eq("192.168.1.1")
    end

    it "returns IP for bracketed IPv6 with port" do
      Utils.parse_ip_address("[::1]:8080").should eq("::1")
    end

    it "returns IP for IPv4 with port" do
      Utils.parse_ip_address("192.168.1.1:8080").should eq("192.168.1.1")
    end

    it "returns IP for plain IPv4 address" do
      Utils.parse_ip_address("192.168.1.1").should eq("192.168.1.1")
    end

    it "returns IP for bracketed IPv6 with port" do
      Utils.parse_ip_address("[::1]:8080").should eq("::1")
    end

    it "returns IP for localhost" do
      Utils.parse_ip_address("localhost").should eq("localhost")
    end

    it "returns nil for empty string" do
      Utils.parse_ip_address("").should be_nil
    end
  end

  describe "private_host?" do
    it "returns true for localhost" do
      Utils.private_host?("localhost").should be_true
    end

    it "returns true for 127.0.0.1" do
      Utils.private_host?("127.0.0.1").should be_true
    end

    it "returns true for 127.0.0.2" do
      Utils.private_host?("127.0.0.2").should be_true
    end

    it "returns true for 192.168.x.x" do
      Utils.private_host?("192.168.1.1").should be_true
    end

    it "returns true for 10.x.x.x" do
      Utils.private_host?("10.0.0.1").should be_true
    end

    it "returns true for 172.16.0.0 range" do
      Utils.private_host?("172.16.0.1").should be_true
    end

    it "returns true for 172.31.255.255" do
      Utils.private_host?("172.31.255.255").should be_true
    end

    it "returns true for 169.254.x.x (link-local)" do
      Utils.private_host?("169.254.1.1").should be_true
    end

    it "returns true for 100.64.x.x (CGN)" do
      Utils.private_host?("100.64.1.1").should be_true
    end

    it "returns true for ::1" do
      Utils.private_host?("::1").should be_true
    end

    it "returns true for 0.0.0.0" do
      Utils.private_host?("0.0.0.0").should be_true
    end

    it "returns false for public IP 8.8.8.8" do
      Utils.private_host?("8.8.8.8").should be_false
    end

    it "returns false for public hostname" do
      Utils.private_host?("example.com").should be_false
    end

    it "returns false for public IP 1.1.1.1" do
      Utils.private_host?("1.1.1.1").should be_false
    end
  end

  describe "validate_proxy_host" do
    it "returns true for public https URL" do
      Utils.validate_proxy_host("https://example.com/image.png").should be_true
    end

    it "returns true for public http URL" do
      Utils.validate_proxy_host("http://example.com/image.png").should be_true
    end

    it "returns false for localhost URL" do
      Utils.validate_proxy_host("http://localhost/image.png").should be_false
    end

    it "returns false for private IP URL" do
      Utils.validate_proxy_host("http://192.168.1.1/image.png").should be_false
    end

    it "returns false for invalid URL" do
      Utils.validate_proxy_host("not-a-url").should be_false
    end

    it "returns false for URL without host" do
      Utils.validate_proxy_host("https://").should be_false
    end

    it "returns false for ftp URL" do
      Utils.validate_proxy_host("ftp://example.com/image.png").should be_false
    end
  end
end

describe "ConfigValidationError" do
  it "formats error message with single invalid feed" do
    invalid = [{"Feed", "http://bad", "Invalid scheme"}]
    error = ConfigValidationError.new(invalid)
    error.message.should contain("Invalid feed URLs found")
    error.message.should contain("Feed")
    error.message.should contain("http://bad")
    error.message.should contain("Invalid scheme")
  end

  it "formats error message with multiple invalid feeds" do
    invalid = [
      {"Feed1", "ftp://bad1", "Invalid scheme"},
      {"Feed2", "not-a-url", "Malformed URL"},
    ]
    error = ConfigValidationError.new(invalid)
    error.message.should contain("Invalid feed URLs found")
    error.message.should contain("Feed1")
    error.message.should contain("Feed2")
  end

  it "stores invalid feeds for programmatic access" do
    invalid = [{"Feed", "http://bad", "Invalid scheme"}]
    error = ConfigValidationError.new(invalid)
    error.invalid_feeds.should eq(invalid)
  end
end

describe "validate_feed_urls!" do
  it "does not raise for valid config" do
    yaml = <<-YAML
      feeds:
        - title: "Tech News"
          url: "https://example.com/feed.xml"
      YAML
    config = Config.from_yaml(yaml)
    validate_feed_urls!(config)
  end

  it "raises for invalid URL scheme" do
    yaml = <<-YAML
      feeds:
        - title: "Bad Feed"
          url: "ftp://example.com/feed.xml"
      YAML
    config = Config.from_yaml(yaml)
    expect_raises(ConfigValidationError) { validate_feed_urls!(config) }
  end

  it "raises for empty URL" do
    yaml = <<-YAML
      feeds:
        - title: "Bad Feed"
          url: ""
      YAML
    config = Config.from_yaml(yaml)
    expect_raises(ConfigValidationError) { validate_feed_urls!(config) }
  end

  it "raises for malformed URL" do
    yaml = <<-YAML
      feeds:
        - title: "Bad Feed"
          url: "not a url"
      YAML
    config = Config.from_yaml(yaml)
    expect_raises(ConfigValidationError) { validate_feed_urls!(config) }
  end

  it "raises for invalid feed in tabs" do
    yaml = <<-YAML
      tabs:
        - name: "Tech"
          feeds:
            - title: "Bad Feed"
              url: "ftp://bad.com"
      YAML
    config = Config.from_yaml(yaml)
    expect_raises(ConfigValidationError) { validate_feed_urls!(config) }
  end

  it "raises with all invalid feeds listed" do
    yaml = <<-YAML
      feeds:
        - title: "Bad1"
          url: "ftp://bad1.com"
        - title: "Bad2"
          url: "not-a-url"
      YAML
    config = Config.from_yaml(yaml)
    begin
      validate_feed_urls!(config)
      fail("Expected ConfigValidationError to be raised")
    rescue ex : ConfigValidationError
      ex.message.should contain("Bad1")
      ex.message.should contain("Bad2")
    end
  end
end
