require "./spec_helper"
require "../src/entities/cluster"
require "../src/entities/story"
require "../src/entities/feed"

describe Quickheadlines::Services::ClusteringService do
  describe "#cluster_uncategorized" do
    it "clusters similar items together" do
      cache = FeedCache.new(nil)
      db = cache.db

      db.exec("DELETE FROM items")
      db.exec("DELETE FROM feeds")
      db.exec("DELETE FROM lsh_bands")

      db.exec(
        "INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?)",
        1_i64, "https://tech.example.com/feed.xml", "Tech News", "https://tech.example.com", "#ff0000", "#ffffff", Time.utc.to_s("%Y-%m-%d %H:%M:%S")
      )
      db.exec(
        "INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?)",
        2_i64, "https://news.example.com/feed.xml", "Tech News 2", "https://news.example.com", "#00ff00", "#000000", Time.utc.to_s("%Y-%m-%d %H:%M:%S")
      )

      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
        1_i64, 1_i64, "OpenAI releases GPT-5 with improved reasoning capabilities today", "https://tech.example.com/gpt5", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0
      )
      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
        2_i64, 2_i64, "OpenAI releases GPT-5 with improved reasoning capabilities now", "https://news.example.com/gpt5", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0
      )
      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
        3_i64, 2_i64, "OpenAI releases GPT-5 with improved reasoning capabilities soon", "https://tech.example.com/gpt5-v2", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0
      )

      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
        10_i64, 1_i64, "Completely different story about cooking", "https://tech.example.com/cooking", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0
      )
      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
        11_i64, 2_i64, "Another unrelated tech story about phones", "https://news.example.com/phones", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0
      )

      service = Quickheadlines::Services::ClusteringService.new(db)
      processed = service.cluster_uncategorized(limit: 10)

      processed.should eq(5)

      cluster_1 = cache.get_cluster_items(1_i64)
      cluster_1.size.should eq(3)

      cluster_10 = cache.get_cluster_items(10_i64)
      cluster_10.size.should eq(1)

      cluster_11 = cache.get_cluster_items(11_i64)
      cluster_11.size.should eq(1)
    end

    it "skips items with insufficient word count" do
      cache = FeedCache.new(nil)
      db = cache.db

      db.exec("DELETE FROM items")
      db.exec("DELETE FROM feeds")
      db.exec("DELETE FROM lsh_bands")

      db.exec(
        "INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?)",
        1_i64, "https://tech.example.com/feed.xml", "Tech News", "https://tech.example.com", "#ff0000", "#ffffff", Time.utc.to_s("%Y-%m-%d %H:%M:%S")
      )

      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
        1_i64, 1_i64, "Short title", "https://tech.example.com/1", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0
      )
      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position) VALUES (?, ?, ?, ?, ?, ?, ?)",
        2_i64, 1_i64, "OpenAI releases new AI model today for users", "https://tech.example.com/2", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0
      )

      service = Quickheadlines::Services::ClusteringService.new(db)
      processed = service.cluster_uncategorized(limit: 10)

      processed.should eq(2)

      signature_1 = cache.get_item_signature(1_i64)
      signature_1.should be_nil

      signature_2 = cache.get_item_signature(2_i64)
      signature_2.should_not be_nil
    end
  end

  describe "#recluster_all" do
    it "clears existing clustering and reclusters all items" do
      cache = FeedCache.new(nil)
      db = cache.db

      db.exec("DELETE FROM items")
      db.exec("DELETE FROM feeds")
      db.exec("DELETE FROM lsh_bands")

      db.exec(
        "INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?)",
        1_i64, "https://tech.example.com/feed.xml", "Tech News", "https://tech.example.com", "#ff0000", "#ffffff", Time.utc.to_s("%Y-%m-%d %H:%M:%S")
      )
      db.exec(
        "INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?)",
        2_i64, "https://news.example.com/feed.xml", "Tech News 2", "https://news.example.com", "#00ff00", "#000000", Time.utc.to_s("%Y-%m-%d %H:%M:%S")
      )

      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position, cluster_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        1_i64, 1_i64, "OpenAI releases GPT-5 with improved reasoning capabilities today", "https://tech.example.com/1", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0, 1_i64
      )
      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position, cluster_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        2_i64, 2_i64, "OpenAI releases GPT-5 with improved reasoning capabilities now", "https://tech.example.com/2", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0, 1_i64
      )

      service = Quickheadlines::Services::ClusteringService.new(db)
      processed = service.recluster_all(limit: 10)

      processed.should eq(2)

      cluster_1 = cache.get_cluster_items(1_i64)
      cluster_1.size.should eq(2)
    end
  end

  describe "#get_all_clusters_from_db" do
    it "returns cluster information with representative and others" do
      cache = FeedCache.new(nil)
      db = cache.db

      db.exec("DELETE FROM items")
      db.exec("DELETE FROM feeds")
      db.exec("DELETE FROM lsh_bands")

      db.exec(
        "INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (?, ?, ?, ?, ?, ?, ?)",
        1_i64, "https://tech.example.com/feed.xml", "Tech News", "https://tech.example.com", "#ff0000", "#ffffff", Time.utc.to_s("%Y-%m-%d %H:%M:%S")
      )

      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position, cluster_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        1_i64, 1_i64, "OpenAI releases GPT-5 with improved reasoning", "https://tech.example.com/1", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0, 1_i64
      )
      db.exec(
        "INSERT INTO items (id, feed_id, title, link, pub_date, version, position, cluster_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        2_i64, 1_i64, "OpenAI announces GPT-5 with improved reasoning", "https://tech.example.com/2", Time.utc.to_s("%Y-%m-%d %H:%M:%S"), 1, 0, 1_i64
      )

      service = Quickheadlines::Services::ClusteringService.new(db)
      clusters = service.get_all_clusters_from_db

      clusters.size.should eq(1)
      clusters[0].size.should eq(2)
      clusters[0].representative.title.should eq("OpenAI releases GPT-5 with improved reasoning")
      clusters[0].others.size.should eq(1)
      clusters[0].others[0].title.should eq("OpenAI announces GPT-5 with improved reasoning")
    end
  end
end
