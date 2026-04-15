require "spec"
require "../src/api"
require "../src/storage"
require "../src/models"
require "../src/dtos/story_dto"
require "../src/dtos/cluster_dto"

describe "API Response Types" do
  describe TabResponse do
    it "creates with name" do
      response = TabResponse.new("technology")
      response.name.should eq("technology")
    end
  end

  describe ItemResponse do
    it "creates with required fields" do
      response = ItemResponse.new(
        title: "Test Title",
        link: "https://example.com/article"
      )
      response.title.should eq("Test Title")
      response.link.should eq("https://example.com/article")
      response.version.should be_nil
      response.pub_date.should be_nil
    end

    it "creates with all fields" do
      response = ItemResponse.new(
        title: "Test Title",
        link: "https://example.com/article",
        version: "1.0.0",
        pub_date: 1700000000000_i64
      )
      response.title.should eq("Test Title")
      response.version.should eq("1.0.0")
      response.pub_date.should eq(1700000000000_i64)
    end
  end

  describe FeedResponse do
    it "creates with required fields" do
      response = FeedResponse.new(
        tab: "tech",
        url: "https://example.com/feed.xml",
        title: "Example Feed",
        site_link: "https://example.com",
        display_link: "example.com",
        items: [] of ItemResponse,
        total_item_count: 0
      )
      response.tab.should eq("tech")
      response.url.should eq("https://example.com/feed.xml")
      response.title.should eq("Example Feed")
      response.items.should be_empty
    end

    it "includes optional fields" do
      response = FeedResponse.new(
        tab: "tech",
        url: "https://example.com/feed.xml",
        title: "Example Feed",
        site_link: "https://example.com",
        display_link: "example.com",
        favicon: "/favicons/icon.png",
        favicon_data: "/favicons/icon.png",
        header_color: "#ff0000",
        header_text_color: "#ffffff",
        items: [] of ItemResponse,
        total_item_count: 10
      )
      response.favicon.should eq("/favicons/icon.png")
      response.header_color.should eq("#ff0000")
      response.header_text_color.should eq("#ffffff")
      response.total_item_count.should eq(10)
    end
  end

  describe TimelineItemResponse do
    it "creates with required fields" do
      response = TimelineItemResponse.new(
        id: "feed::https://example.com/article",
        title: "Test Title",
        link: "https://example.com/article",
        feed_title: "Test Feed",
        feed_url: "https://example.com/feed.xml",
        feed_link: "https://example.com"
      )
      response.id.should eq("feed::https://example.com/article")
      response.title.should eq("Test Title")
      response.feed_title.should eq("Test Feed")
    end

    it "includes cluster information" do
      response = TimelineItemResponse.new(
        id: "feed::https://example.com/article",
        title: "Test Title",
        link: "https://example.com/article",
        feed_title: "Test Feed",
        feed_url: "https://example.com/feed.xml",
        feed_link: "https://example.com",
        cluster_id: "123",
        is_representative: true,
        cluster_size: 5
      )
      response.cluster_id.should eq("123")
      response.is_representative?.should be_true
      response.cluster_size.should eq(5)
    end
  end

  describe FeedsPageResponse do
    it "creates with required fields" do
      response = FeedsPageResponse.new(
        tabs: [TabResponse.new("tech"), TabResponse.new("news")],
        active_tab: "tech",
        feeds: [] of FeedResponse,
        software_releases: [] of FeedResponse,
        clustering: false,
        updated_at: 1700000000000_i64
      )
      response.tabs.size.should eq(2)
      response.active_tab.should eq("tech")
      response.feeds.should be_empty
      response.software_releases.should be_empty
      response.clustering?.should be_false
    end
  end

  describe TimelinePageResponse do
    it "creates with required fields" do
      response = TimelinePageResponse.new(
        items: [] of TimelineItemResponse,
        has_more: false,
        total_count: 0,
        clustering: false
      )
      response.items.should be_empty
      response.has_more?.should be_false
      response.total_count.should eq(0)
      response.clustering?.should be_false
    end
  end

  describe QuickHeadlines::DTOs::StoryResponse do
    it "creates with required fields" do
      response = QuickHeadlines::DTOs::StoryResponse.new(
        id: "123",
        title: "Test Story",
        link: "https://example.com/story"
      )
      response.id.should eq("123")
      response.title.should eq("Test Story")
      response.link.should eq("https://example.com/story")
    end
  end

  describe QuickHeadlines::DTOs::ClusterResponse do
    it "calculates cluster size from others" do
      story = QuickHeadlines::DTOs::StoryResponse.new(
        id: "1",
        title: "Test Story",
        link: "https://example.com/story"
      )
      others = [
        QuickHeadlines::DTOs::StoryResponse.new(id: "2", title: "Story 2", link: "https://example.com/2"),
        QuickHeadlines::DTOs::StoryResponse.new(id: "3", title: "Story 3", link: "https://example.com/3"),
      ]
      response = QuickHeadlines::DTOs::ClusterResponse.new(
        id: "cluster-1",
        representative: story,
        others: others
      )
      response.cluster_size.should eq(3)
    end

    it "allows explicit cluster size" do
      story = QuickHeadlines::DTOs::StoryResponse.new(
        id: "1",
        title: "Test Story",
        link: "https://example.com/story"
      )
      response = QuickHeadlines::DTOs::ClusterResponse.new(
        id: "cluster-1",
        representative: story,
        others: [] of QuickHeadlines::DTOs::StoryResponse,
        cluster_size: 10
      )
      response.cluster_size.should eq(10)
    end
  end

  describe ClusterItemsResponse do
    it "creates with required fields" do
      response = ClusterItemsResponse.new(
        cluster_id: "123",
        items: [] of QuickHeadlines::DTOs::StoryResponse
      )
      response.cluster_id.should eq("123")
      response.items.should be_empty
    end
  end
end

describe "API Module" do
  describe ".feed_to_response" do
    it "converts FeedData to FeedResponse" do
      cache = FeedCache.new(nil)
      FeedCache.instance = cache

      feed_data = FeedData.new(
        title: "Test Feed",
        url: "https://test-#{rand(99999)}.example.com/feed.xml",
        site_link: "https://example.com",
        header_color: nil,
        header_text_color: nil,
        items: [
          Item.new("Item 1", "https://example.com/1", nil),
          Item.new("Item 2", "https://example.com/2", nil),
        ]
      )

      response = Api.feed_to_response(feed_data, "tech", 2, 10)

      response.title.should eq("Test Feed")
      response.url.should eq(feed_data.url)
      response.tab.should eq("tech")
      response.items.size.should eq(2)
      response.total_item_count.should eq(2)
    end
  end
end
