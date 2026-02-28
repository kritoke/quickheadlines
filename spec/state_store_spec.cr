require "spec"
require "../src/models"
require "../src/config"

describe "StateStore" do
  describe "initialization" do
    it "starts with empty state" do
      state = StateStore.get
      state.feeds.should be_empty
      state.tabs.should be_empty
      state.software_releases.should be_empty
      state.config_title.should eq("Quick Headlines")
      state.config.should be_nil
      state.is_clustering.should be_false
      state.is_refreshing.should be_false
    end
  end

  describe "updates" do
    it "updates feeds atomically" do
      feed = FeedData.new(
        title: "Test Feed",
        url: "https://test.com/feed.xml",
        site_link: "https://test.com",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )

      StateStore.update { |s| s.copy_with(feeds: [feed]) }

      StateStore.feeds.size.should eq(1)
      StateStore.feeds.first.title.should eq("Test Feed")
    end

    it "updates is_clustering atomically" do
      StateStore.update { |s| s.copy_with(is_clustering: true) }
      StateStore.is_clustering?.should be_true

      StateStore.update { |s| s.copy_with(is_clustering: false) }
      StateStore.is_clustering?.should be_false
    end

    it "updates is_refreshing atomically" do
      StateStore.update { |s| s.copy_with(is_refreshing: true) }
      StateStore.is_refreshing?.should be_true

      StateStore.update { |s| s.copy_with(is_refreshing: false) }
      StateStore.is_refreshing?.should be_false
    end
  end

  describe "thread safety" do
    it "handles sequential updates without crashing" do
      10.times do |i|
        StateStore.update { |s| s.copy_with(is_clustering: i.odd?) }
      end

      final_state = StateStore.get
      # Just verify no crashes - state is deterministic
      final_state.is_clustering.should be_true
    end
  end

  describe "feeds_for_tab_impl" do
    it "finds feeds for a tab" do
      tab = Tab.new("Tech")
      feed = FeedData.new(
        title: "Test Feed",
        url: "https://test.com/feed.xml",
        site_link: "https://test.com",
        header_color: nil,
        header_text_color: nil,
        items: [] of Item
      )
      tab.feeds << feed

      StateStore.update { |s| s.copy_with(tabs: [tab]) }

      feeds = StateStore.feeds_for_tab_impl("Tech")
      feeds.size.should eq(1)
      feeds.first.title.should eq("Test Feed")
    end

    it "returns empty for non-existent tab" do
      feeds = StateStore.feeds_for_tab_impl("NonExistent")
      feeds.should be_empty
    end
  end
end
