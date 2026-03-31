require "athena"

@[ASRA::Name(strategy: :camelcase)]
class QuickHeadlines::DTOs::ClusterResponse
  include ASR::Serializable

  property id : String

  property representative : QuickHeadlines::DTOs::StoryResponse

  property others : Array(QuickHeadlines::DTOs::StoryResponse)

  property cluster_size : Int32

  def initialize(
    @id : String,
    @representative : QuickHeadlines::DTOs::StoryResponse,
    @others : Array(QuickHeadlines::DTOs::StoryResponse) = [] of QuickHeadlines::DTOs::StoryResponse,
    @cluster_size : Int32 = 1,
  )
    @cluster_size = 1 + others.size
  end

  def self.from_entity(cluster : QuickHeadlines::Entities::Cluster) : QuickHeadlines::DTOs::ClusterResponse
    new(
      id: cluster.id,
      representative: QuickHeadlines::DTOs::StoryResponse.from_entity(cluster.representative),
      others: cluster.others.map { |story| QuickHeadlines::DTOs::StoryResponse.from_entity(story) },
      cluster_size: cluster.size
    )
  end
end

@[ASRA::Name(strategy: :camelcase)]
class QuickHeadlines::DTOs::ClustersResponse
  include ASR::Serializable

  property clusters : Array(QuickHeadlines::DTOs::ClusterResponse)

  property total_count : Int32

  def initialize(
    @clusters : Array(QuickHeadlines::DTOs::ClusterResponse),
    @total_count : Int32 = 0,
  )
  end
end
