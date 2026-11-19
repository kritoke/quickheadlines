require "./spec_helper"
require "../src/services/clustering_service"

private STORY = "OpenAI releases GPT-5 with improved reasoning capabilities"

private def setup_db(cache : FeedCache) : Nil
  db = cache.db
  db.exec("DELETE FROM items")
  db.exec("DELETE FROM feeds")
  db.exec("DELETE FROM lsh_bands")
  now = Time.utc.to_s("%Y-%m-%d %H:%M:%S")
  (1..3).each do |i|
    db.exec("INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (?, ?, ?, ?, NULL, NULL, ?)",
      i.to_i64, "https://site#{i}.example.com/feed", "Feed #{i}", "https://site#{i}.example.com", now)
  end
end

private def add_item(cache : FeedCache, id : Int64, feed_id : Int64, title : String) : Nil
  cache.db.exec("INSERT INTO items (id, feed_id, title, link, normalized_link, pub_date, version) VALUES (?, ?, ?, ?, ?, ?, 1)",
    id, feed_id, title, "https://x.example.com/#{id}", "https://x.example.com/#{id}", Time.utc.to_s("%Y-%m-%d %H:%M:%S"))
end

describe "ClusteringService#compute_item_cluster (incremental)" do
  it "joins a new similar story to the existing cluster's representative" do
    cache = create_test_feed_cache
    setup_db(cache)
    service = QuickHeadlines::Services::ClusteringService.new(cache.db_service)

    add_item(cache, 1_i64, 1_i64, "#{STORY} today")
    service.compute_item_cluster(1_i64, "#{STORY} today", cache, 1_i64).should eq(1_i64)

    add_item(cache, 2_i64, 2_i64, "#{STORY} now")
    service.compute_item_cluster(2_i64, "#{STORY} now", cache, 2_i64).should eq(1_i64)

    # Third source: whichever member it best-matches, it must land in cluster 1.
    add_item(cache, 3_i64, 3_i64, "#{STORY} soon")
    service.compute_item_cluster(3_i64, "#{STORY} soon", cache, 3_i64).should eq(1_i64)

    cache.clustering_store.get_item_cluster_id(1_i64).should eq(1_i64)
    cache.clustering_store.get_cluster_items(1_i64).size.should eq(3)
  end

  it "joins via a non-representative member's cluster id" do
    cache = create_test_feed_cache
    setup_db(cache)
    service = QuickHeadlines::Services::ClusteringService.new(cache.db_service)

    add_item(cache, 1_i64, 1_i64, "Completely unrelated cooking story about pasta sauces")
    service.compute_item_cluster(1_i64, "Completely unrelated cooking story about pasta sauces", cache, 1_i64)
    add_item(cache, 2_i64, 2_i64, "#{STORY} now")
    service.compute_item_cluster(2_i64, "#{STORY} now", cache, 2_i64)
    # Simulate item 2 being a non-representative member of cluster 1.
    cache.clustering_store.assign_cluster(2_i64, 1_i64)

    add_item(cache, 3_i64, 3_i64, "#{STORY} now")
    service.compute_item_cluster(3_i64, "#{STORY} now", cache, 3_i64).should eq(1_i64)
  end

  it "does not cluster a dissimilar story" do
    cache = create_test_feed_cache
    setup_db(cache)
    service = QuickHeadlines::Services::ClusteringService.new(cache.db_service)

    add_item(cache, 1_i64, 1_i64, "#{STORY} today")
    service.compute_item_cluster(1_i64, "#{STORY} today", cache, 1_i64)
    add_item(cache, 2_i64, 2_i64, "Local bakery wins regional sourdough competition again")
    service.compute_item_cluster(2_i64, "Local bakery wins regional sourdough competition again", cache, 2_i64).should eq(2_i64)
    cache.clustering_store.get_item_cluster_id(1_i64).should eq(1_i64)
  end

  it "skips candidates from the same feed" do
    cache = create_test_feed_cache
    setup_db(cache)
    service = QuickHeadlines::Services::ClusteringService.new(cache.db_service)

    add_item(cache, 1_i64, 1_i64, "#{STORY} today")
    service.compute_item_cluster(1_i64, "#{STORY} today", cache, 1_i64)
    add_item(cache, 2_i64, 1_i64, "#{STORY} today")
    service.compute_item_cluster(2_i64, "#{STORY} today", cache, 1_i64).should eq(2_i64)
  end
end

describe "ClusteringEngine.find_similar_pairs_lsh dense ids" do
  it "maps LSH positions back to the original Int64 ids, skipping unclusterable items" do
    big = Int64::MAX - 10
    items = [
      QuickHeadlines::Services::ClusteringItem.new(id: 5_i64, title: "Too short", feed_id: 1_i64, feed_url: "https://a.example.com/feed"),
      QuickHeadlines::Services::ClusteringItem.new(id: big, title: "#{STORY} today", feed_id: 1_i64, feed_url: "https://a.example.com/feed"),
      QuickHeadlines::Services::ClusteringItem.new(id: 7_i64, title: "Short one", feed_id: 2_i64, feed_url: "https://b.example.com/feed"),
      QuickHeadlines::Services::ClusteringItem.new(id: 3_000_000_000_i64, title: "Local bakery wins regional sourdough competition again", feed_id: 2_i64, feed_url: "https://b.example.com/feed"),
      QuickHeadlines::Services::ClusteringItem.new(id: big + 5, title: "#{STORY} now", feed_id: 3_i64, feed_url: "https://c.example.com/feed"),
    ]

    pairs = QuickHeadlines::Services::ClusteringEngine.find_similar_pairs_lsh(items)
    pairs.size.should eq(1)
    {pairs[0][0], pairs[0][1]}.to_a.sort.should eq([big, big + 5])

    rep_map = QuickHeadlines::Services::ClusteringEngine.cluster_items(items)
    rep_map[big].sort.should eq([big, big + 5])
    rep_map[3_000_000_000_i64].should eq([3_000_000_000_i64])
    rep_map.has_key?(5_i64).should be_false
  end
end
