require "athena"

class Quickheadlines::Events::StoryFetchedEvent
  getter stories : Array(Quickheadlines::Entities::Story)

  def initialize(@stories : Array(Quickheadlines::Entities::Story))
  end
end
