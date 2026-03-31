require "spec"
require "../src/storage"
require "../src/config"
require "../src/entities/feed"
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
    describe "#find_by_url" do
      it "returns nil for non-existent feed" do
        cache = FeedCache.new(nil)
        repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db)
        repo.find_by_url("https://nonexistent-#{rand(99999)}.example.com/feed.xml").should be_nil
      end

      it "returns feed when it exists" do
        cache = FeedCache.new(nil)
        repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db)
        test_url = unique_url

        feed = QuickHeadlines::Entities::Feed.new(
          id: "1",
          title: "Test Feed",
          url: test_url,
          site_link: "https://test.example.com",
          header_color: "#ff0000"
        )
        repo.save(feed)

        found = repo.find_by_url(test_url)
        found.should_not be_nil
        found.as(QuickHeadlines::Entities::Feed).title.should eq("Test Feed")
        found.as(QuickHeadlines::Entities::Feed).header_color.should eq("#ff0000")
      end
    end

    describe "#save" do
      it "inserts new feed" do
        cache = FeedCache.new(nil)
        repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db)
        test_url = unique_url

        feed = QuickHeadlines::Entities::Feed.new(
          id: "1",
          title: "New Feed",
          url: test_url,
          site_link: "https://new.example.com"
        )

        repo.save(feed)

        found = repo.find_by_url(test_url)
        found.should_not be_nil
        found.as(QuickHeadlines::Entities::Feed).title.should eq("New Feed")
      end
    end

    describe "#count_items" do
      it "returns correct count after upserting items" do
        cache = FeedCache.new(nil)
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
        cache = FeedCache.new(nil)
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

    describe "#delete_by_url" do
      it "removes feed and its items" do
        cache = FeedCache.new(nil)
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
          ]
        )
        repo.upsert_with_items(feed_data)

        repo.count_items(test_url).should eq(1)

        repo.delete_by_url(test_url)

        repo.count_items(test_url).should eq(0)
      end
    end

    describe "#find_by_pattern" do
      it "finds feed by exact URL" do
        cache = FeedCache.new(nil)
        repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db)
        test_url = "https://pattern-test-#{rand(99999)}.example.com/feed.xml"

        feed = QuickHeadlines::Entities::Feed.new(
          id: "1",
          title: "Test Feed",
          url: test_url,
          site_link: ""
        )
        repo.save(feed)

        found = repo.find_by_url(test_url)
        found.should_not be_nil
        found.as(QuickHeadlines::Entities::Feed).title.should eq("Test Feed")
      end
    end
  end

  describe QuickHeadlines::Repositories::StoryRepository do
    describe "#deduplicate" do
      it "returns false for non-existent title" do
        cache = FeedCache.new(nil)
        repo = QuickHeadlines::Repositories::StoryRepository.new(cache.db)
        repo.deduplicate(1, "Non-existent Title-#{rand(99999)}").should be_false
      end

      it "returns true when title exists" do
        cache = FeedCache.new(nil)
        repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db)
        story_repo = QuickHeadlines::Repositories::StoryRepository.new(cache.db)
        test_url = unique_url

        feed_data = FeedData.new(
          title: "Test Feed",
          url: test_url,
          site_link: "https://test.example.com",
          header_color: nil,
          header_text_color: nil,
          items: [
            Item.new("Existing Title #{rand(99999)}", "https://example.com/1", nil),
          ]
        )
        repo.upsert_with_items(feed_data)

        feed_id = cache.get_feed_id(test_url)
        feed_id.should_not be_nil

        story_repo.deduplicate(feed_id.as(Int64), "Existing Title #{rand(99999)}").should be_false
      end
    end
  end
end
