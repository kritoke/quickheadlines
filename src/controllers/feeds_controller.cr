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
    software_releases_snapshot = state.software_releases
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
                       tab_feeds = tabs_snapshot.find { |t| t.name.downcase == active_tab.downcase }
                       if tab_feeds
                         tab_feeds.feeds.select { |f| !f.failed? }.map { |f| Api.feed_to_response(f, active_tab, cache.item_count(f.url), item_limit) }
                       else
                         [] of FeedResponse
                       end
                     end

    software_releases_response = software_releases_snapshot.map do |feed|
      Api.feed_to_response(feed, "", cache.item_count(feed.url), item_limit)
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

  @[ARTA::Get(path: "/api/feed_more")]
  def feed_more(request : ATH::Request) : FeedResponse
    url = request.query_params["url"]?
    limit = validate_limit(request.query_params["limit"]?, 10)
    offset = validate_offset(request.query_params["offset"]?)

    if url.nil? || url.strip.empty?
      raise Athena::Framework::Exception::BadRequest.new("Missing 'url' parameter")
    end

    config = StateStore.config
    if config.nil?
      raise Athena::Framework::Exception::ServiceUnavailable.new("Configuration not loaded")
    end

    all_feeds = config.feeds + config.tabs.flat_map(&.feeds)

    if feed_config = all_feeds.find { |feed| feed.url == url }
      tab_name = ""
      if tab = config.tabs.find { |tab_item| tab_item.feeds.any? { |feed_item| feed_item.url == url } }
        tab_name = tab.name
      end

      cache = @feed_cache

      current_count = 0
      if cached_feed = cache.get(url)
        current_count = cached_feed.items.size
      end

      needed_count = offset + limit

      if current_count < needed_count
        db_fetch_limit = StateStore.config.try(&.db_fetch_limit) || 500
        fetch_feed(feed_config, needed_count + 50, db_fetch_limit, nil)
      end

      if data = cache.get(url)
        trimmed_items = data.items[offset...Math.min(offset + limit, data.items.size)]

        items_response = trimmed_items.map do |item|
          ItemResponse.new(
            title: item.title,
            link: item.link,
            version: item.version,
            pub_date: item.pub_date.try(&.to_unix_ms),
            comment_url: item.comment_url,
            commentary_url: item.commentary_url
          )
        end

        FeedResponse.new(
          tab: tab_name,
          url: data.url,
          title: data.title,
          site_link: data.site_link,
          display_link: data.display_link,
          favicon: data.favicon,
          favicon_data: data.favicon_data,
          header_color: data.header_color,
          items: items_response,
          total_item_count: cache.item_count(url)
        )
      else
        raise Athena::Framework::Exception::ServiceUnavailable.new("Failed to retrieve feed data")
      end
    else
      raise Athena::Framework::Exception::NotFound.new("Feed not found")
    end
  end
end