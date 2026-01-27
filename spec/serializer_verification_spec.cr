require "spec"
require "athena"
require "../src/dtos/story_dto"
require "../src/dtos/feed_dto"
require "../src/dtos/cluster_dto"

describe "Athena Serializer Verification" do
  describe "StoryDTO" do
    it "serializes with camelCase keys" do
      dto = Quickheadlines::DTOs::StoryDTO.new(
        id: "test-id",
        title: "Test Story",
        link: "https://example.com",
        pub_date: 1234567890000_i64,
        feed_title: "Test Feed",
        feed_url: "https://feed.example.com",
        feed_link: "https://feed.example.com/link",
        favicon: "favicon.png",
        favicon_data: "data:image/png;base64,abc123",
        header_color: "#FF0000"
      )

      # Use Athena's serializer with JSON format
      serializer = ASR::Serializer.new
      json = serializer.serialize(dto, "json")
      parsed = JSON.parse(json)

      # Verify camelCase keys
      parsed.as_h.keys.should contain("id")
      parsed.as_h.keys.should contain("title")
      parsed.as_h.keys.should contain("link")
      parsed.as_h.keys.should contain("pubDate")
      parsed.as_h.keys.should contain("feedTitle")
      parsed.as_h.keys.should contain("feedUrl")
      parsed.as_h.keys.should contain("feedLink")
      parsed.as_h.keys.should contain("favicon")
      parsed.as_h.keys.should contain("faviconData")
      parsed.as_h.keys.should contain("headerColor")

      # Verify NO snake_case keys
      parsed.as_h.keys.should_not contain("pub_date")
      parsed.as_h.keys.should_not contain("feed_title")
      parsed.as_h.keys.should_not contain("feed_url")
      parsed.as_h.keys.should_not contain("feed_link")
      parsed.as_h.keys.should_not contain("favicon_data")
      parsed.as_h.keys.should_not contain("header_color")
    end
  end

  describe "FeedDTO" do
    it "serializes with camelCase keys" do
      dto = Quickheadlines::DTOs::FeedDTO.new(
        id: "feed-id",
        title: "Test Feed",
        url: "https://feed.example.com",
        site_link: "https://example.com",
        header_color: "#FF0000",
        favicon: "favicon.png",
        favicon_data: "data:image/png;base64,abc123"
      )

      # Use Athena's serializer with JSON format
      serializer = ASR::Serializer.new
      json = serializer.serialize(dto, "json")
      parsed = JSON.parse(json)

      # Verify camelCase keys
      parsed.as_h.keys.should contain("id")
      parsed.as_h.keys.should contain("title")
      parsed.as_h.keys.should contain("url")
      parsed.as_h.keys.should contain("siteLink")
      parsed.as_h.keys.should contain("headerColor")
      parsed.as_h.keys.should contain("favicon")
      parsed.as_h.keys.should contain("faviconData")

      # Verify NO snake_case keys
      parsed.as_h.keys.should_not contain("site_link")
      parsed.as_h.keys.should_not contain("header_color")
      parsed.as_h.keys.should_not contain("favicon_data")
    end
  end

  describe "ClusterDTO" do
    it "serializes with camelCase keys" do
      story_dto = Quickheadlines::DTOs::StoryDTO.new(
        id: "story-id",
        title: "Test Story",
        link: "https://example.com",
        feed_title: "Test Feed",
        feed_url: "https://feed.example.com",
        feed_link: "https://feed.example.com/link"
      )

      dto = Quickheadlines::DTOs::ClusterDTO.new(
        id: "cluster-id",
        representative: story_dto,
        others: [] of Quickheadlines::DTOs::StoryDTO,
        cluster_size: 1
      )

      # Use Athena's serializer with JSON format
      serializer = ASR::Serializer.new
      json = serializer.serialize(dto, "json")
      parsed = JSON.parse(json)

      # Verify camelCase keys
      parsed.as_h.keys.should contain("id")
      parsed.as_h.keys.should contain("representative")
      parsed.as_h.keys.should contain("others")
      parsed.as_h.keys.should contain("clusterSize")

      # Verify NO snake_case keys
      parsed.as_h.keys.should_not contain("cluster_size")
    end
  end
end
