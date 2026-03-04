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

  describe AppState do
    it "initializes with defaults" do
      StateStore.clear
      state = AppState.new
      state.feeds.should be_empty
      state.software_releases.should be_empty
      state.tabs.should be_empty
      state.config_title.should eq("Quick Headlines")
      state.config.should be_nil
      state.clustering?.should be_false
      state.refreshing?.should be_false
    end

    it "finds feeds for tab" do
      state = AppState.new
      tab = Tab.new("Tech")
      feed = FeedData.new(
        title: "Test Feed",
        url: "https://example.com/feed.xml",
        site_link: "",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      tab.feeds << feed
      state.tabs << tab

      feeds = AppState.feeds_for_tab("Tech")
      feeds.size.should eq(1)
      feeds.first.title.should eq("Test Feed")
    end

    it "returns empty array for non-existent tab" do
      feeds = AppState.feeds_for_tab("NonExistent")
      feeds.should be_empty
    end

    it "collects all timeline items" do
      state = AppState.new

      feed1 = FeedData.new(
        title: "Feed 1",
        url: "https://feed1.com/feed.xml",
        site_link: "https://feed1.com",
        header_color: nil,
        header_text_color: nil,
        items: [
          Item.new("Item 1", "https://feed1.com/1", Time.utc(2024, 1, 2)),
          Item.new("Item 2", "https://feed1.com/2", Time.utc(2024, 1, 1)),
        ]
      )
      state.feeds << feed1

      tab = Tab.new("Tech")
      feed2 = FeedData.new(
        title: "Feed 2",
        url: "https://feed2.com/feed.xml",
        site_link: "https://feed2.com",
        header_color: nil,
        header_text_color: nil,
        items: [
          Item.new("Item 3", "https://feed2.com/3", Time.utc(2024, 1, 3)),
        ]
      )
      tab.feeds << feed2
      state.tabs << tab

      items = AppState.all_timeline_items
      items.size.should eq(3)
      # Should be sorted by date descending (newest first)
      items[0].item.title.should eq("Item 3")
      items[1].item.title.should eq("Item 1")
      items[2].item.title.should eq("Item 2")
    end
  end
end
