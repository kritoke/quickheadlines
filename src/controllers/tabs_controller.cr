require "./api_base_controller"

class QuickHeadlines::Controllers::TabsController < QuickHeadlines::Controllers::ApiBaseController
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
end
