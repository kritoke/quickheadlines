require "./api_base_controller"

class QuickHeadlines::Controllers::TabsController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/tabs")]
  def tabs : QuickHeadlines::DTOs::TabsResponse
    state = StateStore.get
    tabs_snapshot = state.tabs

    if tabs_snapshot.empty?
      config = StateStore.config
      if config
        tabs_snapshot = config.tabs
      end
    end

    tabs_response = tabs_snapshot.map do |tab|
      QuickHeadlines::DTOs::TabResponse.new(name: tab.name)
    end

    QuickHeadlines::DTOs::TabsResponse.new(tabs: tabs_response)
  end
end
