require "spec"
require "../src/module"
require "../src/models"
require "../src/config"
require "../src/services/app_state_service"

describe "StateStore" do
  # Wire AppStateService before tests (normally done by AppBootstrap)
  before_all do
    StateStore.service = QuickHeadlines::Services::AppStateService.new
  end

  describe "initialization" do
    it "starts with empty state" do
      state = StateStore.get
      state.feeds.should be_empty
      state.tabs.should be_empty
      state.config_title.should eq("Quick Headlines")
      state.config.should be_nil
      state.clustering.should be_false
      state.refreshing.should be_false
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

      StateStore.update(&.copy_with(feeds: [feed]))

      StateStore.feeds.size.should eq(1)
      StateStore.feeds.first.title.should eq("Test Feed")
    end

    it "updates clustering atomically" do
      StateStore.clustering = true
      StateStore.clustering?.should be_true

      StateStore.clustering = false
      StateStore.clustering?.should be_false
    end

    it "updates refreshing atomically" do
      StateStore.refreshing = true
      StateStore.refreshing?.should be_true

      StateStore.refreshing = false
      StateStore.refreshing?.should be_false
    end
  end

  describe "thread safety" do
    it "handles sequential updates without crashing" do
      10.times do |i|
        StateStore.update(&.copy_with(clustering: i.odd?))
      end

      final_state = StateStore.get
      # Just verify no crashes - state is deterministic
      final_state.clustering.should be_true
    end
  end
end
