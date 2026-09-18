# Adapter and registry for the feed fetcher plugin surface.
# This file introduces a small, stable interface so alternate fetcher
# implementations can be registered at runtime for testing or replacement.

module FetcherAdapter
  # Implementations must provide a fetch method compatible with
  # the existing FeedFetcher.fetch signature.
  abstract def fetch(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
end

# Default adapter delegates to the existing FeedFetcher singleton.
class DefaultFetcherAdapter
  include FetcherAdapter

  def initialize
  end

  def fetch(feed : Feed, display_item_limit : Int32, db_fetch_limit : Int32, previous_data : FeedData? = nil) : FeedData
    FeedFetcher.instance.fetch(feed, display_item_limit, db_fetch_limit, previous_data)
  end
end

# Simple registry to hold the active adapter. By default, it uses the
# DefaultFetcherAdapter which delegates to the current FeedFetcher.
module FetcherRegistry
  @@impl : FetcherAdapter? = nil

  def self.impl : FetcherAdapter
    @@impl ||= DefaultFetcherAdapter.new
    @@impl.not_nil!
  end

  def self.register_impl(adapter : FetcherAdapter)
    @@impl = adapter
  end
end
