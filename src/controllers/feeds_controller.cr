require "./api_base_controller"
require "../constants"
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
                       tab_feeds = tabs_snapshot.find { |tab| tab.name.downcase == active_tab.downcase }
                       if tab_feeds
                         tab_feeds.feeds.select { |feed| !feed.failed? }.map { |feed| Api.feed_to_response(feed, active_tab, cache.item_count(feed.url), item_limit) }
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
        fetch_feed(feed_config, needed_count + QuickHeadlines::Constants::FETCH_BUFFER_ITEMS, db_fetch_limit, nil)
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

  @[ARTA::Get(path: "/api/config")]
  def config : ATH::View(QuickHeadlines::DTOs::ConfigResponse)
    config = StateStore.config
    refresh_minutes = config.try(&.refresh_minutes) || 10
    item_limit = config.try(&.item_limit) || 20
    debug = config.try(&.debug?) || false

    view(QuickHeadlines::DTOs::ConfigResponse.new(
      refresh_minutes: refresh_minutes,
      item_limit: item_limit,
      debug: debug
    ))
  end

  @[ARTA::Get(path: "/api/tabs")]
  def tabs : ATH::View(TabsResponse)
    state = StateStore.get
    tabs_snapshot = state.tabs

    if tabs_snapshot.empty?
      config = StateStore.config
      if config
        tabs_snapshot = config.tabs
      end
    end

    tabs_response = tabs_snapshot.map do |tab|
      TabResponse.new(name: tab.name)
    end

    view(TabsResponse.new(tabs: tabs_response))
  end

  @[ARTA::Post(path: "/api/header_color")]
  def save_header_color(request : ATH::Request) : ATH::Response
    body_io = request.body
    return ATH::Response.new("Missing request body", 400) if body_io.nil?

    body = JSON.parse(read_body_safe(body_io))
    feed_url = body["feed_url"]?.try(&.as_s?)
    color = body["color"]?.try(&.as_s?)
    text_color = body["text_color"]?.try(&.as_s?)

    if feed_url.nil? || color.nil? || text_color.nil? ||
       feed_url.strip.empty? || color.empty? || text_color.empty?
      return ATH::Response.new("Missing feed_url, color, or text_color", 400)
    end

    config = StateStore.config
    return ATH::Response.new("Configuration not loaded", 500) if config.nil?

    if has_manual_color_override?(config, feed_url)
      return ATH::Response.new("Skipped: manual config exists", 200)
    end

    normalized_url = feed_url.strip.rstrip('/').gsub(/\/rss(\.xml)?$/i, "")
    cache = @feed_cache
    db_url = cache.find_feed_url_by_pattern(normalized_url) || feed_url

    cache.update_header_colors(db_url, color, text_color)
    ATH::Response.new("OK", 200)
  rescue ex : IO::EOFError
    ATH::Response.new("Request body too large", 413, HTTP::Headers{"content-type" => "text/plain"})
  rescue ex
    Log.for("quickheadlines.http").error(exception: ex) { "Header color save error" }
    ATH::Response.new("Internal server error", 500)
  end

  private def has_manual_color_override?(config, feed_url) : Bool
    config.tabs.any? do |tab|
      tab.feeds.any? do |feed|
        feed.url == feed_url && !feed.header_color.nil?
      end
    end
  end
end
