require "spec"
require "../src/storage"
require "../src/config"
require "../src/entities/story"
require "../src/entities/cluster"
require "../src/repositories/feed_repository"
require "../src/repositories/story_repository"
require "../src/repositories/cluster_repository"

def unique_url
  "https://test-#{Time.utc.to_unix}-#{rand(10000)}.example.com/feed.xml"
end

describe "Repositories" do
  describe QuickHeadlines::Repositories::FeedRepository do
    describe "#count_items" do
      it "returns correct count after upserting items" do
        cache = create_test_feed_cache
        repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db)
        test_url = unique_url

        feed_data = FeedData.new(
          title: "Test Feed",
          url: test_url,
          site_link: "https://test.example.com",
          header_color: nil,
          header_text_color: nil,
          items: [
            Item.new("Title 1", "https://example.com/1", nil),
            Item.new("Title 2", "https://example.com/2", nil),
          ]
        )
        repo.upsert_with_items(feed_data)

        repo.count_items(test_url).should eq(2)
      end
    end

    describe "#find_with_items" do
      it "returns feed with items" do
        cache = create_test_feed_cache
        repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db)
        test_url = unique_url

        feed_data = FeedData.new(
          title: "Test Feed",
          url: test_url,
          site_link: "https://test.example.com",
          header_color: "#ff0000",
          header_text_color: "#ffffff",
          items: [
            Item.new("Title 1", "https://example.com/1", nil),
            Item.new("Title 2", "https://example.com/2", nil),
          ]
        )
        repo.upsert_with_items(feed_data)

        found = repo.find_with_items(test_url)
        found.should_not be_nil
        found.as(FeedData).title.should eq("Test Feed")
        found.as(FeedData).items.size.should eq(2)
      end
    end
  end
end
