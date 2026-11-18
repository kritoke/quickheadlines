require "./spec_helper"

private def feed_with_items(url : String, titles : Array(String)) : FeedData
  items = titles.map_with_index { |title, idx| Item.new(title, "#{url}/item-#{idx}", Time.utc) }
  FeedData.new(title: "Feed #{url}", url: url, site_link: url, header_color: nil, header_text_color: nil, items: items)
end

describe "FeedRepository#upsert_with_items" do
  it "attaches items to the correct (newly inserted) feed id" do
    cache = create_test_feed_cache
    repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db_service)
    repo.upsert_with_items(feed_with_items("http://a.test/rss", ["a1", "a2"]))
    repo.upsert_with_items(feed_with_items("http://b.test/rss", ["b1"]))

    rows = cache.db.query_all(
      "SELECT f.url, i.title FROM items i JOIN feeds f ON f.id = i.feed_id ORDER BY i.title",
      as: {String, String})
    rows.should eq([{"http://a.test/rss", "a1"}, {"http://a.test/rss", "a2"}, {"http://b.test/rss", "b1"}])
  end

  it "rolls back the feed row and earlier batches when a later batch fails" do
    cache = create_test_feed_cache
    db = cache.db
    db.exec(<<-SQL)
      CREATE TRIGGER fail_on_poison BEFORE INSERT ON items
      WHEN NEW.title = 'POISON'
      BEGIN SELECT RAISE(ABORT, 'poisoned'); END
      SQL
    repo = QuickHeadlines::Repositories::FeedRepository.new(cache.db_service)
    size = QuickHeadlines::Constants::BATCH_INSERT_SIZE
    titles = (0...size).map { |i| "ok-#{i}" } + ["POISON"] # poison lands in the 2nd batch

    expect_raises(Exception, /poisoned/) do
      repo.upsert_with_items(feed_with_items("http://rollback.test/rss", titles))
    end

    db.scalar("SELECT COUNT(*) FROM feeds WHERE url = 'http://rollback.test/rss'").as(Int64).should eq(0)
    db.scalar("SELECT COUNT(*) FROM items").as(Int64).should eq(0)
  end
end
