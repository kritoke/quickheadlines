require "athena"

class Quickheadlines::Repositories::StoryRepository
  def find_all : Array(Quickheadlines::Entities::Story)
    # TODO: Implement find all stories
    [] of Quickheadlines::Entities::Story
  end

  def find(id : String) : Quickheadlines::Entities::Story?
    # TODO: Implement find story by id
    nil
  end

  def save(story : Quickheadlines::Entities::Story) : Quickheadlines::Entities::Story
    # TODO: Implement save story
    story
  end
end
