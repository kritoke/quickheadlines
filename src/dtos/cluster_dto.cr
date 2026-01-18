require "athena"

class Quickheadlines::DTOs::ClusterDTO
  include ASR::Serializable

  property id : String
  property representative : Quickheadlines::DTOs::StoryDTO
  property others : Array(Quickheadlines::DTOs::StoryDTO)
  property cluster_size : Int32

  def initialize(
    @id : String,
    @representative : Quickheadlines::DTOs::StoryDTO,
    @others : Array(Quickheadlines::DTOs::StoryDTO) = [] of Quickheadlines::DTOs::StoryDTO,
    @cluster_size : Int32 = 1
  )
    @cluster_size = 1 + others.size
  end

  def self.from_entity(cluster : Quickheadlines::Entities::Cluster) : Quickheadlines::DTOs::ClusterDTO
    new(
      id: cluster.id,
      representative: Quickheadlines::DTOs::StoryDTO.from_entity(cluster.representative),
      others: cluster.others.map { |story| Quickheadlines::DTOs::StoryDTO.from_entity(story) },
      cluster_size: cluster.size
    )
  end
end
