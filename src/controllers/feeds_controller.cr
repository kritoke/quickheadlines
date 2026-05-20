require "./api_base_controller"
require "../fetcher/refresh_loop"

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

    has_valid_feeds = feeds_snapshot.any?(&.failed?.!) || tabs_snapshot.any?(&.feeds.any?(&.failed?.!))

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
end
