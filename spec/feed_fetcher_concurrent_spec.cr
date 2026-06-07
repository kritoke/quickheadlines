require "spec"
require "./spec_helper"
require "../src/fetcher/feed_fetcher_concurrent"
require "../src/fetcher/refresh_health_monitor"

# Spec for RefreshLoop::FeedFetcherConcurrent.
#
# The module is required directly at the top of the spec so the
# constant is bound before the `describe` block runs. The constant
# `OVERALL_FETCH_TIMEOUT` and the `best_available_feed` resolver are
# pure (no I/O, no singleton access) so they're the easy wins. The
# `fetch_all` end-to-end path uses `FeedFetcher.instance.fetch`
# which makes a real HTTP request — for that path we wire up a
# minimal FeedFetcher with `create_test_feed_cache` from
# spec_helper and feed it an unreachable URL so the call fails
# fast.
describe RefreshLoop::FeedFetcherConcurrent do
  describe "OVERALL_FETCH_TIMEOUT" do
    it "is 10 minutes" do
      RefreshLoop::FeedFetcherConcurrent::OVERALL_FETCH_TIMEOUT.should eq(10.minutes)
    end
  end

  describe "#best_available_feed" do
    it "returns the fresh-good feed when fetched is good" do
      f = test_feed("http://a.test/rss")
      fetched = good_feed(f.url)
      existing = good_feed("http://b.test/rss")
      result = RefreshLoop::FeedFetcherConcurrent.best_available_feed(f, fetched, existing)
      result.should eq(fetched)
    end

    it "returns existing-good when fetched-bad (a good cached value beats a fresh failure)" do
      f = test_feed("http://a.test/rss")
      fetched_bad = bad_feed(f.url)
      existing_good = good_feed("http://other.test/rss")
      # The actual implementation returns existing_good in this case
      # (the comment in the source says "fresh-good > stale-good >
      # fresh-bad > stale-bad" but the code returns existing_good
      # when fetched is bad and existing is good — i.e. any good
      # beats any bad). This test documents the *actual* behavior
      # so a future refactor that changes the priority will fail
      # here and force a conscious decision.
      result = RefreshLoop::FeedFetcherConcurrent.best_available_feed(f, fetched_bad, existing_good)
      result.should eq(existing_good)
    end

    it "returns existing-good when fetched-bad and existing-good (skips the bad fetch, returns existing)" do
      f = test_feed("http://a.test/rss")
      fetched_bad = bad_feed(f.url)
      existing_good = good_feed("http://other.test/rss")
      result = RefreshLoop::FeedFetcherConcurrent.best_available_feed(f, fetched_bad, existing_good)
      result.should eq(existing_good)
    end

    it "returns existing-good when fetched is nil" do
      f = test_feed("http://a.test/rss")
      existing_good = good_feed("http://other.test/rss")
      result = RefreshLoop::FeedFetcherConcurrent.best_available_feed(f, nil, existing_good)
      result.should eq(existing_good)
    end

    it "returns existing-bad when fetched is nil" do
      f = test_feed("http://a.test/rss")
      existing_bad = bad_feed("http://other.test/rss", "old failure")
      result = RefreshLoop::FeedFetcherConcurrent.best_available_feed(f, nil, existing_bad)
      result.should eq(existing_bad)
    end

    it "returns fetched-bad when existing is nil" do
      f = test_feed("http://a.test/rss")
      fetched_bad = bad_feed(f.url, "new failure")
      result = RefreshLoop::FeedFetcherConcurrent.best_available_feed(f, fetched_bad, nil)
      result.should eq(fetched_bad)
    end
  end

  describe "#fetch_all" do
    it "returns an empty hash for an empty config" do
      semaphore = RefreshLoop::SemaphorePool.new
      all_configs = {} of String => Feed
      existing = {} of String => FeedData
      config = build_minimal_config

      result = RefreshLoop::FeedFetcherConcurrent.fetch_all(all_configs, existing, config, semaphore)
      result.should be_empty
    end

    it "returns a single error-feed for one feed that fails to fetch" do
      # Wire up a minimal FeedFetcher so the end-to-end path doesn't
      # raise. The feed uses an unreachable .invalid URL which will
      # fail quickly (DNS resolution fails for .invalid TLD).
      FeedFetcher.instance = FeedFetcher.new(create_test_feed_cache)

      semaphore = RefreshLoop::SemaphorePool.new
      bad = Feed.from_yaml(<<-YAML)
        title: Unreachable
        url: http://unreachable.invalid/rss
        YAML
      all_configs = {bad.url => bad}
      existing = {} of String => FeedData
      config = build_minimal_config

      result = RefreshLoop::FeedFetcherConcurrent.fetch_all(all_configs, existing, config, semaphore)
      result.size.should eq(1)
      result[bad.url].error_message.should_not be_nil
    end
  end
end

# Helpers to construct FeedData records with the few fields that
# `best_available_feed` and the priority logic look at.
def good_feed(url : String) : FeedData
  FeedData.new(
    title: "Good #{url}",
    url: url,
    site_link: url,
    header_color: nil,
    header_text_color: nil,
    items: [] of Item
  )
end

def bad_feed(url : String, error : String = "boom") : FeedData
  FeedData.new(
    title: "Bad #{url}",
    url: url,
    site_link: url,
    header_color: nil,
    header_text_color: nil,
    items: [] of Item,
    error_message: error
  )
end

def test_feed(url : String) : Feed
  Feed.from_yaml(<<-YAML)
    title: T
    url: #{url}
    YAML
end

# Minimal Config for fetch_all: only the fields the function reads
# (`item_limit`, `db_fetch_limit`, `debug?`).
def build_minimal_config : Config
  yaml = <<-YAML
    cache_dir: #{Dir.tempdir}
    db_path: #{File.join(Dir.tempdir, "qh_test_ffc_#{Process.pid}_#{Random.rand(10000)}.db")}
    refresh_minutes: 30
    item_limit: 5
    db_fetch_limit: 50
    feeds: []
    tabs: []
    YAML
  Config.from_yaml(yaml)
end
