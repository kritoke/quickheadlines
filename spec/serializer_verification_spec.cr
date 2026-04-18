require "spec"
require "json"
require "../src/dtos/story_dto"
require "../src/dtos/cluster_dto"

describe "JSON Serializable DTO Verification" do
  describe "StoryResponse" do
    it "serializes with snake_case keys" do
      dto = QuickHeadlines::DTOs::StoryResponse.new(
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

      json = dto.to_json
      parsed = JSON.parse(json)

      parsed.as_h.keys.should contain("id")
      parsed.as_h.keys.should contain("title")
      parsed.as_h.keys.should contain("link")
      parsed.as_h.keys.should contain("pub_date")
      parsed.as_h.keys.should contain("feed_title")
      parsed.as_h.keys.should contain("feed_url")
      parsed.as_h.keys.should contain("feed_link")
      parsed.as_h.keys.should contain("favicon")
      parsed.as_h.keys.should contain("favicon_data")
      parsed.as_h.keys.should contain("header_color")

      parsed.as_h.keys.should_not contain("pubDate")
      parsed.as_h.keys.should_not contain("feedTitle")
      parsed.as_h.keys.should_not contain("feedUrl")
      parsed.as_h.keys.should_not contain("feedLink")
      parsed.as_h.keys.should_not contain("faviconData")
      parsed.as_h.keys.should_not contain("headerColor")
    end
  end

  describe "ClusterResponse" do
    it "serializes with snake_case keys" do
      story_response = QuickHeadlines::DTOs::StoryResponse.new(
        id: "story-id",
        title: "Test Story",
        link: "https://example.com",
        feed_title: "Test Feed",
        feed_url: "https://feed.example.com",
        feed_link: "https://feed.example.com/link"
      )

      dto = QuickHeadlines::DTOs::ClusterResponse.new(
        id: "cluster-id",
        representative: story_response,
        others: [] of QuickHeadlines::DTOs::StoryResponse,
        cluster_size: 1
      )

      json = dto.to_json
      parsed = JSON.parse(json)

      parsed.as_h.keys.should contain("id")
      parsed.as_h.keys.should contain("representative")
      parsed.as_h.keys.should contain("others")
      parsed.as_h.keys.should contain("cluster_size")

      parsed.as_h.keys.should_not contain("clusterSize")
    end
  end
end
