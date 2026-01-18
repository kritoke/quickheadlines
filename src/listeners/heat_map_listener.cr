require "athena"

class Quickheadlines::Listeners::HeatMapListener
  def initialize(@heat_map_service : Quickheadlines::Services::HeatMapService); end

  def on_story_fetched(event : Quickheadlines::Events::StoryFetchedEvent) : Nil
    stories = event.stories
    
    # Apply your 'Hotness' algorithm:
    # Heat = (Weight_Source * Recent_Clustering_Frequency) / Time_Delta
    @heat_map_service.calculate_and_persist_heat(stories)
  end
end
