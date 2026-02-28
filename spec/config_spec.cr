require "spec"
require "../src/config"
require "../src/models"

describe "Config Validation" do
  describe "Feed validation" do
    it "parses valid feed configuration" do
      yaml = <<-YAML
        feeds:
          - title: "Tech News"
            url: "https://example.com/feed.xml"
        YAML
      config = Config.from_yaml(yaml)
      config.feeds.size.should eq(1)
      config.feeds.first.title.should eq("Tech News")
      config.feeds.first.url.should eq("https://example.com/feed.xml")
    end

    it "parses feed with header colors" do
      yaml = <<-YAML
        feeds:
          - title: "Tech News"
            url: "https://example.com/feed.xml"
            header_color: "#ff0000"
            header_text_color: "#ffffff"
        YAML
      config = Config.from_yaml(yaml)
      config.feeds.first.header_color.should eq("#ff0000")
      config.feeds.first.header_text_color.should eq("#ffffff")
    end

    it "parses feed with auth configuration" do
      yaml = <<-YAML
        feeds:
          - title: "Private Feed"
            url: "https://example.com/private.xml"
            auth:
              type: "bearer"
              token: "secret-token"
        YAML
      config = Config.from_yaml(yaml)
      feed = config.feeds.first
      feed.auth.should_not be_nil
      feed.auth!.type.should eq("bearer")
      feed.auth!.token.should eq("secret-token")
    end

    it "parses feed with retry configuration" do
      yaml = <<-YAML
        feeds:
          - title: "Slow Feed"
            url: "https://example.com/slow.xml"
            max_retries: 5
            retry_delay: 10
            timeout: 60
        YAML
      config = Config.from_yaml(yaml)
      feed = config.feeds.first
      feed.max_retries.should eq(5)
      feed.retry_delay.should eq(10)
      feed.timeout.should eq(60)
    end

    it "parses tab configuration" do
      yaml = <<-YAML
        tabs:
          - name: "Technology"
            feeds:
              - title: "TechCrunch"
                url: "https://techcrunch.com/feed"
        YAML
      config = Config.from_yaml(yaml)
      config.tabs.size.should eq(1)
      config.tabs.first.name.should eq("Technology")
      config.tabs.first.feeds.size.should eq(1)
    end

    it "parses software releases configuration" do
      yaml = <<-YAML
        software_releases:
          repos:
            - "crystal-lang/crystal"
            - "crystal-lang/shards"
        YAML
      config = Config.from_yaml(yaml)
      config.software_releases.should_not be_nil
      config.software_releases!.repos.size.should eq(2)
    end

    it "uses default values for missing fields" do
      yaml = <<-YAML
        feeds:
          - title: "Test"
            url: "https://example.com/feed.xml"
        YAML
      config = Config.from_yaml(yaml)
      config.refresh_minutes.should eq(10)
      config.item_limit.should eq(20)
      config.db_fetch_limit.should eq(500)
      config.server_port.should eq(3030)
      config.cache_retention_hours.should eq(336)
      config.max_cache_size_mb.should eq(100)
    end

    it "allows custom configuration values" do
      yaml = <<-YAML
        refresh_minutes: 15
        item_limit: 30
        db_fetch_limit: 1000
        server_port: 8080
        cache_retention_hours: 168
        max_cache_size_mb: 200
        page_title: "My Headlines"
        feeds:
          - title: "Test"
            url: "https://example.com/feed.xml"
      YAML
      config = Config.from_yaml(yaml)
      config.refresh_minutes.should eq(15)
      config.item_limit.should eq(30)
      config.db_fetch_limit.should eq(1000)
      config.server_port.should eq(8080)
      config.cache_retention_hours.should eq(168)
      config.max_cache_size_mb.should eq(200)
      config.page_title.should eq("My Headlines")
    end

    it "parses clustering configuration" do
      yaml = <<-YAML
        clustering:
          enabled: true
          run_on_startup: false
          threshold: 0.5
          max_items: 10000
        feeds:
          - title: "Test"
            url: "https://example.com/feed.xml"
      YAML
      config = Config.from_yaml(yaml)
      config.clustering.should_not be_nil
      cluster = config.clustering!
      cluster.enabled?.should eq(true)
      cluster.run_on_startup?.should eq(false)
      cluster.threshold.should eq(0.5)
      cluster.max_items.should eq(10000)
    end

    it "parses rate limiting configuration" do
      yaml = <<-YAML
        rate_limiting:
          enabled: true
          max_entries: 5000
          categories:
            expensive:
              limit: 10
              window_minutes: 60
        feeds:
          - title: "Test"
            url: "https://example.com/feed.xml"
      YAML
      config = Config.from_yaml(yaml)
      config.rate_limiting.should_not be_nil
      rate_limit = config.rate_limiting!
      rate_limit.enabled?.should eq(true)
      rate_limit.max_entries.should eq(5000)
    end

    it "parses http client configuration" do
      yaml = <<-YAML
        http_client:
          connect_timeout: 30
          timeout: 60
          max_redirects: 5
          user_agent: "MyBot/1.0"
        feeds:
          - title: "Test"
            url: "https://example.com/feed.xml"
      YAML
      config = Config.from_yaml(yaml)
      config.http_client.should_not be_nil
      http_config = config.http_client!
      http_config.connect_timeout.should eq(30)
      http_config.timeout.should eq(60)
      http_config.max_redirects.should eq(5)
      http_config.user_agent.should eq("MyBot/1.0")
    end
  end
end
