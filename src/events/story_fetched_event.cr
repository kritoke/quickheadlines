require "athena"

class QuickHeadlines::Events::StoryFetchedEvent
  getter stories : Array(QuickHeadlines::Entities::Story)

  def initialize(@stories : Array(QuickHeadlines::Entities::Story))
  end
end
