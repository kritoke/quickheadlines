require "./api_base_controller"
require "../fetcher/refresh_loop"

class QuickHeadlines::Controllers::TimelineController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/timeline")]
  def timeline(request : ATH::Request) : QuickHeadlines::DTOs::TimelinePageResponse
    check_rate_limit!(request, "api_timeline", 180, 60)

    default_limit = StateStore.config.try(&.db_fetch_limit) || 500
    default_days = (StateStore.config.try(&.cache_retention_hours) || 168) / 24
    limit = validate_limit(request.query_params["limit"]?, default_limit, max: 1000)
    offset = validate_offset(request.query_params["offset"]?)
    days = validate_days(request.query_params["days"]?, default_days.to_i32)
    tab = request.query_params["tab"]?

    allowed_feed_urls = resolve_feed_urls(tab)

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

    QuickHeadlines::DTOs::TimelinePageResponse.new(
      items: result.items,
      has_more: result.has_more?,
      total_count: result.total_count,
      clustering: StateStore.clustering?
    )
  end

  private def resolve_feed_urls(tab : String?) : Array(String)
    return [] of String unless tab && tab.downcase != "all"

    state = StateStore.get
    found_tab = state.tabs.find { |_t| _t.name.downcase == tab.downcase }

    if found_tab.nil? || found_tab.feeds.empty?
      feeds_snapshot, cached_tabs = load_feeds_from_cache_fallback(@feed_cache)
      found_tab = cached_tabs.find { |cached_tab| cached_tab[:name].downcase == tab.downcase }
      if found_tab
        return found_tab[:feeds].map(&.url)
      elsif feeds_snapshot.any? { |feed| feed.url == tab }
        return [tab]
      end
      return [] of String
    end

    found_tab.feeds.map(&.url)
  end
end
