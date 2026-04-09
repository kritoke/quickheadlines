require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::TimelineController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/timeline")]
  def timeline(request : ATH::Request) : TimelinePageResponse
    ip = client_ip(request)
    limiter = RateLimiter.get_or_create("api_timeline:#{ip}", 60, 60)
    unless limiter.allowed?(ip)
      raise ATH::Exception::HTTPException.new(429, "Rate limit exceeded", nil, HTTP::Headers{"Retry-After" => limiter.retry_after(ip).to_s})
    end

    default_limit = StateStore.config.try(&.db_fetch_limit) || 500
    default_days = (StateStore.config.try(&.cache_retention_hours) || 168) / 24
    limit = validate_limit(request.query_params["limit"]?, default_limit, max: 1000)
    offset = validate_offset(request.query_params["offset"]?)
    days = validate_days(request.query_params["days"]?, default_days.to_i32)
    tab = request.query_params["tab"]?

    allowed_feed_urls = [] of String
    if tab && tab.downcase != "all"
      state = StateStore.get
      tabs_snapshot = state.tabs
      found_tab = tabs_snapshot.find { |_t| _t.name.downcase == tab.downcase }

      if found_tab.nil? || found_tab.feeds.empty?
        feeds_snapshot, cached_tabs = load_feeds_from_cache_fallback(@feed_cache)
        found_tab = cached_tabs.find { |cached_tab| cached_tab[:name].downcase == tab.downcase }
        if found_tab
          allowed_feed_urls = found_tab[:feeds].map(&.url)
        elsif feeds_snapshot.any? { |feed| feed.url == tab }
          allowed_feed_urls = [tab]
        end
      else
        allowed_feed_urls = found_tab.feeds.map(&.url)
      end
    end

    story_repo = QuickHeadlines::Repositories::StoryRepository.new(@db_service)
    result = QuickHeadlines::Services::StoryService.get_timeline(
      story_repo,
      limit,
      offset,
      days,
      allowed_feed_urls.empty? ? [] of String : allowed_feed_urls
    )

    if result.total_count < 100 && !StateStore.clustering? && offset == 0
      spawn do
        begin
          config = StateStore.config
          if config
            refresh_all(config)
          end
        rescue ex
          Log.for("quickheadlines.feed").error(exception: ex) { "Background refresh error" }
        end
      end
    end

    TimelinePageResponse.new(
      items: result.items,
      has_more: result.has_more?,
      total_count: result.total_count,
      clustering: StateStore.clustering?
    )
  end
end
