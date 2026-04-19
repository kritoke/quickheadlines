require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::FeedPaginationController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/feed_more")]
  def feed_more(request : ATH::Request) : QuickHeadlines::DTOs::FeedResponse
    url = request.query_params["url"]?
    limit = validate_limit(request.query_params["limit"]?, 10)
    offset = validate_offset(request.query_params["offset"]?)

    if url.nil? || url.strip.empty?
      raise ATH::Exception::BadRequest.new("Missing 'url' parameter")
    end

    check_rate_limit!(request, "feed_more", 30, 60)

    config = StateStore.config
    if config.nil?
      raise ATH::Exception::ServiceUnavailable.new("Configuration not loaded")
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
        FeedFetcher.instance.fetch(feed_config, needed_count + QuickHeadlines::Constants::FETCH_BUFFER_ITEMS, db_fetch_limit, nil)
      end

      if data = cache.get(url)
        QuickHeadlines::Services::FeedService.build_feed_more_response(
          data,
          tab_name,
          offset,
          limit,
          cache,
          cache.item_count(url),
        )
      else
        raise ATH::Exception::ServiceUnavailable.new("Failed to retrieve feed data")
      end
    else
      raise ATH::Exception::NotFound.new("Feed not found")
    end
  end
end
