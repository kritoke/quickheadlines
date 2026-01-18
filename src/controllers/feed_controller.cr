require "athena"

class Quickheadlines::Controllers::FeedController < Athena::Framework::Controller
  # GET /api/feed_list - List all feeds (simplified view)
  @[ARTA::Get(path: "/api/feed_list")]
  def index : Array(Quickheadlines::DTOs::FeedDTO)
    # TODO: Implement index method
    [] of Quickheadlines::DTOs::FeedDTO
  end

  # GET /api/feeds/:id
  @[ARTA::Get(path: "/api/feeds/:id")]
  def show(id : String) : Quickheadlines::DTOs::FeedDTO
    # TODO: Implement show method
    raise Athena::Framework::Exception::NotFound.new("Feed not found")
  end

  # GET /api/feeds/:id/stories
  @[ARTA::Get(path: "/api/feeds/:id/stories")]
  def stories(id : String) : Array(Quickheadlines::DTOs::StoryDTO)
    # TODO: Implement stories method
    [] of Quickheadlines::DTOs::StoryDTO
  end
end
