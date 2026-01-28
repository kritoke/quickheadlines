require "athena"

@[ASRA::Name(strategy: :camelcase)]
class Quickheadlines::DTOs::NewsClusterDTO
  include ASR::Serializable

  property id : String
  property title : String
  property timestamp : String
  property source_count : Int32

  def initialize(
    @id : String,
    @title : String,
    @timestamp : String,
    @source_count : Int32 = 1
  )
  end

  def self.from_cluster(clusters : Array(Quickheadlines::Entities::Cluster)) : Array(Quickheadlines::DTOs::NewsClusterDTO)
    clusters.map do |cluster|
      new(
        id: cluster.id,
        title: cluster.representative.title,
        timestamp: cluster.representative.pub_date.try(&.to_iso8601) || Time.local.to_iso8601,
        source_count: cluster.cluster_size
      )
    end
  end
end
