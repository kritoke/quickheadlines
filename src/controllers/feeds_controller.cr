require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::FeedsController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/feeds")]
  def feeds(request : ATH::Request) : FeedsPageResponse
    raw_tab = request.query_params["tab"]?
    active_tab = raw_tab.presence || "all"

    cache = @feed_cache
    item_limit = StateStore.get.config.try(&.item_limit) || 20

    state = StateStore.get
    feeds_snapshot = state.feeds
    tabs_snapshot = state.tabs
    is_clustering = state.clustering

    total_feeds = feeds_snapshot.size + tabs_snapshot.sum(&.feeds.size)
    if total_feeds == 0
      feeds_snapshot, tabs_snapshot_hash = load_feeds_from_cache_fallback(cache)
      tabs_snapshot = tabs_snapshot_hash.map { |tab| Tab.new(tab[:name], tab[:feeds], tab[:software_releases]) }
    end

    tabs_response = tabs_snapshot.map do |tab|
      TabResponse.new(name: tab.name)
    end

    feeds_response = if active_tab.to_s.downcase == "all"
                       all_feeds_with_tabs = [] of {feed: FeedData, tab_name: String}

                       feeds_snapshot.each do |feed|
                         all_feeds_with_tabs << {feed: feed, tab_name: ""} unless feed.failed?
                       end

                       tabs_snapshot.each do |tab|
                         tab.feeds.each do |feed|
                           all_feeds_with_tabs << {feed: feed, tab_name: tab.name} unless feed.failed?
                         end
                       end

                       all_feeds_with_tabs.map { |entry| Api.feed_to_response(entry[:feed], entry[:tab_name], cache.item_count(entry[:feed].url), item_limit) }
                     else
                       tab_feeds = tabs_snapshot.find { |tab| tab.name.downcase == active_tab.downcase }
                       if tab_feeds
                         tab_feeds.feeds.select { |feed| !feed.failed? }.map { |feed| Api.feed_to_response(feed, active_tab, cache.item_count(feed.url), item_limit) }
                       else
                         [] of FeedResponse
                       end
                     end

    software_releases_response = if active_tab.to_s.downcase == "all"
                                   [] of FeedResponse
                                 else
                                   tab_with_sr = tabs_snapshot.find { |tab| tab.name.downcase == active_tab.downcase }
                                   if tab_with_sr && tab_with_sr.software_releases.present?
                                     tab_with_sr.software_releases.map do |feed|
                                       Api.feed_to_response(feed, active_tab, cache.item_count(feed.url), item_limit)
                                     end
                                   else
                                     [] of FeedResponse
                                   end
                                 end

    FeedsPageResponse.new(
      tabs: tabs_response,
      active_tab: active_tab.to_s,
      feeds: feeds_response,
      software_releases: software_releases_response,
      clustering: is_clustering,
      updated_at: StateStore.updated_at.to_unix_ms
    )
  end
end
