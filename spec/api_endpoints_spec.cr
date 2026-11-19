require "./spec_helper"
require "athena"
require "../src/controllers/feed_pagination_controller"
require "../src/controllers/asset_controller"
require "../src/controllers/cluster_controller"

# Controllers are built via `allocate` with only the collaborators each
# endpoint touches, so no AppBootstrap wiring is needed.
private class TestFeedPaginationController < QuickHeadlines::Controllers::FeedPaginationController
  def self.build(cache : FeedCache) : self
    allocate.tap(&.init_for_test(cache))
  end

  def init_for_test(cache : FeedCache) : Nil
    @feed_cache = cache
  end
end

private class TestAssetController < QuickHeadlines::Controllers::AssetController
  def self.build(actor : FaviconActor) : self
    allocate.tap(&.init_for_test(actor))
  end

  def init_for_test(actor : FaviconActor) : Nil
    @favicon_actor = actor
  end
end

private class TestClusterController < QuickHeadlines::Controllers::ClusterController
  def self.build(db : DatabaseService) : self
    allocate.tap(&.init_for_test(db))
  end

  def init_for_test(db : DatabaseService) : Nil
    @db_service = db
    @clustering_service = nil
  end
end

# FaviconActor rooted in a temp dir; `forced` makes get_or_fetch return a
# fixed path so the controller's basename check can be exercised directly.
private class TestFaviconActor < FaviconActor
  class_property test_dir : String = ""
  property forced : String? = nil

  private def compute_favicon_dir : String
    TestFaviconActor.test_dir
  end

  def get_or_fetch(url : String) : String?
    forced || super
  end
end

private FEED_URL = "https://example.com/feed.xml"

private def make_request(path : String) : AHTTP::Request
  AHTTP::Request.new(HTTP::Request.new("GET", path))
end

private def with_config(feeds_yaml : String, &)
  StateStore.service = QuickHeadlines::Services::AppStateService.new
  config = Config.from_yaml(feeds_yaml)
  StateStore.update(&.copy_with(config: config))
  yield
ensure
  FeedFetcher.fetch_override = nil
end

private def seed_feed(cache : FeedCache, count : Int32) : Nil
  items = (0...count).map do |i|
    Item.new("Story #{i}", "https://example.com/story-#{i}", Time.utc - i.minutes)
  end
  cache.add(FeedData.new("Example", FEED_URL, "https://example.com", nil, nil, items))
end

describe "GET /api/feed_more" do
  it "rejects a missing url with 400" do
    controller = TestFeedPaginationController.build(create_test_feed_cache)
    expect_raises(AHK::Exception::BadRequest) do
      controller.feed_more(make_request("/api/feed_more"))
    end
    expect_raises(AHK::Exception::BadRequest) do
      controller.feed_more(make_request("/api/feed_more?url=%20"))
    end
  end

  it "returns 404 for a feed not in the config" do
    with_config("feeds:\n  - title: Example\n    url: #{FEED_URL}\n") do
      controller = TestFeedPaginationController.build(create_test_feed_cache)
      expect_raises(AHK::Exception::NotFound) do
        controller.feed_more(make_request("/api/feed_more?url=#{URI.encode_www_form("https://unknown.example/rss")}"))
      end
    end
  end

  it "slices offset/limit from the cache without an upstream fetch when enough items are cached" do
    with_config("feeds:\n  - title: Example\n    url: #{FEED_URL}\n") do
      cache = create_test_feed_cache
      seed_feed(cache, 10)
      fetches = 0
      FeedFetcher.fetch_override = ->(_feed : Feed, _limit : Int32, _db_limit : Int32, _prev : FeedData?) do
        fetches += 1
        raise "upstream fetch must not happen"
      end

      controller = TestFeedPaginationController.build(cache)
      resp = controller.feed_more(make_request("/api/feed_more?url=#{URI.encode_www_form(FEED_URL)}&offset=3&limit=4"))

      fetches.should eq(0)
      resp.items.map(&.title).should eq(["Story 3", "Story 4", "Story 5", "Story 6"])
      resp.total_item_count.should eq(10)
    end
  end

  it "goes upstream when the cache does not hold offset+limit items" do
    with_config("tabs:\n  - name: Tech\n    feeds:\n      - title: Example\n        url: #{FEED_URL}\n") do
      cache = create_test_feed_cache
      seed_feed(cache, 2)
      fetches = 0
      FeedFetcher.fetch_override = ->(_feed : Feed, _limit : Int32, _db_limit : Int32, _prev : FeedData?) do
        fetches += 1
        seed_feed(cache, 8)
        cache.get(FEED_URL) || raise "seeded feed missing"
      end

      controller = TestFeedPaginationController.build(cache)
      resp = controller.feed_more(make_request("/api/feed_more?url=#{URI.encode_www_form(FEED_URL)}&offset=5&limit=10"))

      fetches.should eq(1)
      resp.tab.should eq("Tech")
      resp.items.map(&.title).should eq(["Story 5", "Story 6", "Story 7"])
    end
  end
end

describe "GET /api/favicon.png" do
  dir = File.join(Dir.tempdir, "qh_favicons_#{Process.pid}_#{Random.rand(100_000)}")
  Dir.mkdir_p(dir)
  TestFaviconActor.test_dir = dir
  actor = TestFaviconActor.new
  actor.start
  FaviconActor.instance = actor
  controller = TestAssetController.build(actor)

  before_each { actor.forced = nil }

  it "rejects a missing url with 400" do
    expect_raises(AHK::Exception::BadRequest) do
      controller.favicon_png(make_request("/api/favicon.png"))
    end
  end

  it "serves the stored favicon with its content type" do
    site = "https://favicon-present.example.com/"
    hash = FaviconActor.favicon_hash_for_url(QuickHeadlines::CacheUtils.normalize_feed_url(site))
    File.write(File.join(dir, FaviconActor.favicon_filename(hash, "png")), "PNGBYTES")

    resp = controller.favicon_png(make_request("/api/favicon.png?url=#{URI.encode_www_form(site)}"))
    resp.status.code.should eq(200)
    resp.headers["content-type"].should eq("image/png")
    resp.headers["x-content-type-options"].should eq("nosniff")
    resp.content.should eq("PNGBYTES")
  end

  it "returns 404 when no favicon is stored" do
    expect_raises(AHK::Exception::NotFound) do
      controller.favicon_png(make_request("/api/favicon.png?url=#{URI.encode_www_form("https://absent.example.com/")}"))
    end
  end

  it "rejects non-hash basenames even if the file exists" do
    File.write(File.join(dir, "evil.png"), "EVIL")
    actor.forced = "/favicons/evil.png"
    expect_raises(AHK::Exception::NotFound) do
      controller.favicon_png(make_request("/api/favicon.png?url=#{URI.encode_www_form("https://x.example.com/")}"))
    end
  end
end

describe "GET /api/clusters" do
  it "returns only multi-item clusters with representative, others and counts" do
    cache = create_test_feed_cache
    db = cache.db
    db.exec("DELETE FROM items")
    db.exec("DELETE FROM feeds")
    now = Time.utc.to_s("%Y-%m-%d %H:%M:%S")
    db.exec("INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (1, 'https://a.example.com/feed', 'A', 'https://a.example.com', NULL, NULL, ?)", now)
    db.exec("INSERT INTO feeds (id, url, title, site_link, header_color, header_text_color, last_fetched) VALUES (2, 'https://b.example.com/feed', 'B', 'https://b.example.com', NULL, NULL, ?)", now)
    {
      {1, 1, "Rep story", 1},
      {2, 2, "Member story", 1},
      {3, 2, "Second member", 1},
      {4, 1, "Singleton story", 4},
    }.each do |id, feed_id, title, cluster_id|
      db.exec("INSERT INTO items (id, feed_id, title, link, normalized_link, pub_date, version, cluster_id) VALUES (?, ?, ?, ?, ?, ?, 1, ?)",
        id.to_i64, feed_id.to_i64, title, "https://x.example.com/#{id}", "https://x.example.com/#{id}", now, cluster_id.to_i64)
    end

    resp = TestClusterController.build(cache.db_service).clusters(make_request("/api/clusters"))
    resp.total_count.should eq(1)
    resp.clusters.size.should eq(1)
    cluster = resp.clusters.first
    cluster.id.should eq("1")
    cluster.cluster_size.should eq(3)
    cluster.representative.title.should eq("Rep story")
    cluster.others.map(&.title).should eq(["Member story", "Second member"])

    json = JSON.parse(resp.to_json)
    json["total_count"].as_i.should eq(1)
    json["clusters"][0]["representative"]["title"].as_s.should eq("Rep story")
  end
end
