require "./api_base_controller"

class QuickHeadlines::Controllers::ConfigController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/config")]
  def config : QuickHeadlines::DTOs::ConfigResponse
    config = StateStore.config
    refresh_minutes = config.try(&.refresh_minutes) || 10
    item_limit = config.try(&.item_limit) || 20
    debug = config.try(&.debug?) || false

    QuickHeadlines::DTOs::ConfigResponse.new(
      refresh_minutes: refresh_minutes,
      item_limit: item_limit,
      debug: debug
    )
  end
end
