require "athena"

class QuickHeadlines::Repositories::HeatMapRepository
  def save_heat(story_id : String, heat : Float64) : Nil
    # TODO: Implement save heat
  end

  def find_heat(story_id : String) : Float64?
    # TODO: Implement find heat by story id
    nil
  end

  def story_heat(story_ids : Array(String)) : Hash(String, Float64)
    # TODO: Implement find heat for multiple story ids
    {} of String => Float64
  end
end
