require "athena"

class Quickheadlines::Services::HeatMapService
  def initialize(@heat_map_repository : Quickheadlines::Repositories::HeatMapRepository); end

  def calculate_and_persist_heat(stories : Array(Quickheadlines::Entities::Story)) : Nil
    # TODO: Implement heat map calculation
    # Heat = (Weight_Source * Recent_Clustering_Frequency) / Time_Delta
  end

  def get_heat(story_id : String) : Float64?
    # TODO: Implement get heat by story id
    nil
  end
end
