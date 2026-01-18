require "athena"

class Quickheadlines::Controllers::StoryController < Athena::Framework::Controller
  # GET /api/stories
  @[ARTA::Get(path: "/api/stories")]
  def index : Array(Quickheadlines::DTOs::StoryDTO)
    # TODO: Implement index method
    [] of Quickheadlines::DTOs::StoryDTO
  end

  # GET /api/stories/:id
  @[ARTA::Get(path: "/api/stories/:id")]
  def show(id : String) : Quickheadlines::DTOs::StoryDTO
    # TODO: Implement show method
    raise Athena::Framework::Exception::NotFound.new("Story not found")
  end

  # GET /api/stories/:id/cluster
  @[ARTA::Get(path: "/api/stories/:id/cluster")]
  def cluster(id : String) : Quickheadlines::DTOs::ClusterDTO
    # TODO: Implement cluster method
    raise Athena::Framework::Exception::NotFound.new("Cluster not found")
  end
end
