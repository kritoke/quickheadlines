require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::ClusterResponse
  include ASR::Serializable

  property id : String

  property representative : Quickheadlines::DTOs::StoryResponse

  property others : Array(Quickheadlines::DTOs::StoryResponse)

  property cluster_size : Int32

  def initialize(
    @id : String,
    @representative : Quickheadlines::DTOs::StoryResponse,
    @others : Array(Quickheadlines::DTOs::StoryResponse) = [] of Quickheadlines::DTOs::StoryResponse,
    @cluster_size : Int32 = 1,
  )
    @cluster_size = 1 + others.size
  end

  def self.from_entity(cluster : Quickheadlines::Entities::Cluster) : Quickheadlines::DTOs::ClusterResponse
    new(
      id: cluster.id,
      representative: Quickheadlines::DTOs::StoryResponse.from_entity(cluster.representative),
      others: cluster.others.map { |story| Quickheadlines::DTOs::StoryResponse.from_entity(story) },
      cluster_size: cluster.size
    )
  end
end

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::ClustersResponse
  include ASR::Serializable

  property clusters : Array(Quickheadlines::DTOs::ClusterResponse)

  property total_count : Int32

  def initialize(
    @clusters : Array(Quickheadlines::DTOs::ClusterResponse),
    @total_count : Int32 = 0,
  )
  end
end
