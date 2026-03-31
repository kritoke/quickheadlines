require "athena"

class QuickHeadlines::Listeners::HeatMapListener
  def initialize(@heat_map_service : QuickHeadlines::Services::HeatMapService); end

  def on_story_fetched(event : QuickHeadlines::Events::StoryFetchedEvent) : Nil
    stories = event.stories

    # Apply your 'Hotness' algorithm:
    # Heat = (Weight_Source * Recent_Clustering_Frequency) / Time_Delta
    @heat_map_service.calculate_and_persist_heat(stories)
  end
end
