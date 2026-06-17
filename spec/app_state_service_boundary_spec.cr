require "spec"
require "../src/models"
require "../src/config"
require "../src/services/app_state_service"

# Boundary tests for AppStateService — test the public API, not internal implementation.
# These tests verify that AppStateService works as a black box: inputs in, outputs out.

def create_app_state_service : QuickHeadlines::Services::AppStateService
  QuickHeadlines::Services::AppStateService.new
end

def state_sample_feed : FeedData
  FeedData.new(
    title: "Test Feed",
    url: "https://example.com/feed.xml",
    site_link: "https://example.com",
    header_color: nil,
    header_text_color: nil,
    items: [Item.new("Article 1", "https://example.com/1", Time.utc)],
  )
end

describe "AppStateService boundary" do
  describe "#get" do
    it "returns initial empty state" do
      service = create_app_state_service
      state = service.get

      state.feeds.should be_empty
      state.tabs.should be_empty
      state.config_title.should eq("Quick Headlines")
      state.config.should be_nil
      state.clustering.should be_false
      state.refreshing.should be_false
    end
  end

  describe "#update" do
    it "applies transform atomically" do
      service = create_app_state_service

      service.update(&.copy_with(feeds: [state_sample_feed]))
      state = service.get

      state.feeds.size.should eq(1)
      state.feeds.first.title.should eq("Test Feed")
    end

    it "returns the updated state" do
      service = create_app_state_service

      result = service.update(&.copy_with(config_title: "Custom Title"))
      result.config_title.should eq("Custom Title")
    end
  end

  describe "#feeds" do
    it "returns current feeds" do
      service = create_app_state_service
      service.update(&.copy_with(feeds: [state_sample_feed]))

      service.feeds.size.should eq(1)
    end
  end

  describe "#tabs" do
    it "returns current tabs" do
      service = create_app_state_service
      tab = Tab.new(name: "Tech", feeds: [state_sample_feed])
      service.update(&.copy_with(tabs: [tab]))

      service.tabs.size.should eq(1)
      service.tabs.first.name.should eq("Tech")
    end
  end

  describe "#clustering?" do
    it "defaults to false" do
      service = create_app_state_service
      service.clustering?.should be_false
    end

    it "tracks clustering state" do
      service = create_app_state_service
      service.set_clustering(true)
      service.clustering?.should be_true

      service.set_clustering(false)
      service.clustering?.should be_false
    end
  end

  describe "#refreshing?" do
    it "defaults to false" do
      service = create_app_state_service
      service.refreshing?.should be_false
    end

    it "tracks refreshing state" do
      service = create_app_state_service
      service.set_refreshing(true)
      service.refreshing?.should be_true
    end
  end

  describe "#start_clustering_if_idle" do
    it "returns true and starts clustering when idle" do
      service = create_app_state_service
      service.start_clustering_if_idle.should be_true
      service.clustering?.should be_true
    end
  end

  describe "#clear" do
    it "resets to initial state" do
      service = create_app_state_service
      service.update(&.copy_with(feeds: [state_sample_feed], config_title: "Custom"))
      service.set_clustering(true)
      service.set_refreshing(true)

      service.clear
      state = service.get

      state.feeds.should be_empty
      state.config_title.should eq("Quick Headlines")
      service.clustering?.should be_false
      service.refreshing?.should be_false
    end
  end

  describe "#set_config_title" do
    it "updates config title" do
      service = create_app_state_service
      service.set_config_title("My RSS Reader")

      service.config_title.should eq("My RSS Reader")
    end
  end
end
