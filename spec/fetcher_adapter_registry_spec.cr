require "spec"
require "./spec_helper"
require "../src/fetcher/adapter"

# Spec for the FetcherAdapter plugin surface (openspec 0002-mocked-fetcher-adapter).
#
# Verifies that:
# - FetcherRegistry hands out the DefaultFetcherAdapter by default
# - register_impl swaps in an alternate adapter that is actually used
# - the swap requires no network I/O (stub returns synthetic FeedData)
# - the registry is restored to the default afterwards so spec order
#   never leaks a stub into other specs
private class StubFetcherAdapter
  include FetcherAdapter

  getter calls : Int32 = 0

  def fetch(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
    @calls += 1
    FeedData.new(
      title: "Stub #{feed.title}",
      url: feed.url,
      site_link: feed.url,
      header_color: nil,
      header_text_color: nil,
      items: [Item.new(title: "stub item", link: "#{feed.url}/item/1", pub_date: Time.utc)]
    )
  end
end

describe "FetcherRegistry" do
  Spec.after_suite do
    # Restore the default adapter so later specs never see the stub.
    FetcherRegistry.register_impl(DefaultFetcherAdapter.new)
  end

  it "defaults to the DefaultFetcherAdapter" do
    FetcherRegistry.impl.should be_a(DefaultFetcherAdapter)
  end

  it "returns the same adapter instance on repeated lookups" do
    FetcherRegistry.impl.should be(FetcherRegistry.impl)
  end

  it "swaps to a registered alternate adapter" do
    stub_adapter = StubFetcherAdapter.new
    FetcherRegistry.register_impl(stub_adapter)
    FetcherRegistry.impl.should be(stub_adapter)
  end

  it "routes fetch calls through the registered adapter (no network)" do
    feed = Feed.from_yaml(<<-YAML)
      title: T
      url: http://stub.test/rss
      YAML
    stub_adapter = StubFetcherAdapter.new
    FetcherRegistry.register_impl(stub_adapter)

    result = FetcherRegistry.impl.fetch(feed, 5, 50, nil)

    result.url.should eq("http://stub.test/rss")
    result.title.should eq("Stub T")
    result.items.size.should eq(1)
    result.items.first.title.should eq("stub item")
    result.failed?.should be_false
    stub_adapter.calls.should eq(1)
  end
end
