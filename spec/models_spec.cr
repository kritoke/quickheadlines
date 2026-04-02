require "spec"
require "../src/models"
require "../src/config"

describe "Models" do
  describe Item do
    it "creates with title and link" do
      item = Item.new("Test Title", "https://example.com/article", nil)
      item.title.should eq("Test Title")
      item.link.should eq("https://example.com/article")
      item.pub_date.should be_nil
      item.version.should be_nil
    end

    it "creates with all fields" do
      pub_date = Time.utc(2024, 1, 15)
      item = Item.new("Test Title", "https://example.com/article", pub_date, "1.0.0")
      item.title.should eq("Test Title")
      item.link.should eq("https://example.com/article")
      item.pub_date.should eq(pub_date)
      item.version.should eq("1.0.0")
    end
  end

  describe FeedData do
    it "creates with required fields" do
      feed = FeedData.new(
        title: "Test Feed",
        url: "https://example.com/feed.xml",
        site_link: "https://example.com",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      feed.title.should eq("Test Feed")
      feed.url.should eq("https://example.com/feed.xml")
      feed.site_link.should eq("https://example.com")
    end

    it "handles display_header_color" do
      feed = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      feed.display_header_color.should eq("transparent")

      feed2 = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: "  #ff0000  ",
        header_text_color: nil,
        items: [] of Item
      )
      feed2.display_header_color.should eq("#ff0000")
    end

    it "handles display_header_text_color" do
      feed = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      feed.display_header_text_color.should be_nil

      feed2 = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: "  #ffffff  ",
        items: [] of Item
      )
      feed2.display_header_text_color.should eq("#ffffff")
    end

    it "handles display_link" do
      feed = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      feed.display_link.should eq("https://example.com/feed.xml")

      feed2 = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "https://example.com",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      feed2.display_link.should eq("https://example.com")
    end

    it "reports failed? correctly" do
      feed = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      feed.failed?.should be_false

      feed2 = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item,
        error_message: "Failed to fetch"
      )
      feed2.failed?.should be_true
    end
  end

  describe Tab do
    it "creates with name" do
      tab = Tab.new("Technology")
      tab.name.should eq("Technology")
      tab.feeds.should be_empty
      tab.software_releases.should be_empty
    end

    it "can add feeds" do
      tab = Tab.new("Tech")
      feed = FeedData.new(
        title: "Test",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      tab.feeds << feed
      tab.feeds.size.should eq(1)
    end
  end

  describe StateStore do
    it "initializes with defaults" do
      StateStore.clear
      state = StateStore.get
      state.feeds.should be_empty
      state.software_releases.should be_empty
      state.tabs.should be_empty
      state.config_title.should eq("Quick Headlines")
      state.config.should be_nil
      state.clustering.should be_false
      state.refreshing.should be_false
    end

  end
end
