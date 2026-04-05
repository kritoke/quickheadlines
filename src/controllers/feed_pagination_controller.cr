require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::FeedPaginationController < QuickHeadlines::Controllers::ApiBaseController
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
end
