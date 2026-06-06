require "./api_base_controller"

class QuickHeadlines::Controllers::FeedsController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/feeds")]
  def feeds(request : AHTTP::Request) : QuickHeadlines::DTOs::FeedsPageResponse
    check_rate_limit!(request, "api_feeds", QuickHeadlines::Constants::API_CACHE_TTL_SECONDS, 60)

    raw_tab = request.query_params["tab"]?
    active_tab = raw_tab.presence || "all"

    cache = @feed_cache
    item_limit = StateStore.get.config.try(&.item_limit) || 20

    state = StateStore.get
    feeds_snapshot = state.feeds
    tabs_snapshot = state.tabs
    is_clustering = state.clustering

    # Check if we have any successful (non-failed) feeds available
    # A successful feed is one where !failed? returns true
    has_valid_feeds = has_successful_feeds?(feeds_snapshot, tabs_snapshot)

    unless has_valid_feeds
      feeds_snapshot, tabs_snapshot_hash = load_feeds_from_cache_fallback(cache)
      tabs_snapshot = tabs_snapshot_hash.map { |tab| Tab.new(tab[:name], tab[:feeds], tab[:software_releases]) }
    end

    QuickHeadlines::Services::FeedService.build_feeds_page(
      feeds_snapshot,
      tabs_snapshot,
      active_tab,
      is_clustering,
      cache,
      item_limit,
    )
  end

  # Check if we have any successful (non-failed) feeds available
  private def has_successful_feeds?(feeds : Array(FeedData), tabs : Array(Tab)) : Bool
    # Check main feeds for any successful ones
    return true if feeds.any? { |feed| !feed.failed? }
    # Check tabs for any feeds that are successful
    tabs.any? { |tab| tab.feeds.any? { |feed| !feed.failed? } }
  end
end
