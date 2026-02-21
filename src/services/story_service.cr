require "../repositories/story_repository"
require "../repositories/cluster_repository"
require "../dtos/story_dto"
require "../dtos/cluster_dto"
require "../api"

module Quickheadlines::Services
  class StoryService
    @story_repository : Quickheadlines::Repositories::StoryRepository
    @cluster_repository : Quickheadlines::Repositories::ClusterRepository

    def initialize(
      @story_repository : Quickheadlines::Repositories::StoryRepository,
      @cluster_repository : Quickheadlines::Repositories::ClusterRepository
    )
    end

    def get_timeline(limit : Int32, offset : Int32, days : Int32?) : TimelineResult
      items = @story_repository.find_timeline_items(limit, offset, days)
      total_count = @story_repository.count_timeline_items(days)
      has_more = offset + limit < total_count

      timeline_items = items.map do |item|
        TimelineItemResponse.new(
          id: item.id.to_s,
          title: item.title,
          link: item.link,
          pub_date: item.pub_date.try(&.to_unix_ms),
          feed_title: item.feed_title,
          feed_url: item.feed_url,
          feed_link: item.feed_link,
          favicon: item.favicon,
          header_color: item.header_color,
          header_text_color: item.header_text_color,
          cluster_id: item.cluster_id.try(&.to_s),
          is_representative: item.is_representative,
          cluster_size: item.cluster_size
        )
      end

      TimelineResult.new(
        items: timeline_items,
        has_more: has_more,
        total_count: total_count
      )
    end

    def get_clusters : ClustersResult
      clusters = @cluster_repository.find_all

      cluster_responses = clusters.map do |cluster|
        Quickheadlines::DTOs::ClusterResponse.from_entity(cluster)
      end

      ClustersResult.new(
        clusters: cluster_responses,
        total_count: cluster_responses.size
      )
    end

    def get_cluster_items(cluster_id : String) : ClusterItemsResult
      id = cluster_id.to_i64?

      if id.nil?
        return ClusterItemsResult.new(
          cluster_id: cluster_id,
          items: [] of Quickheadlines::DTOs::StoryResponse
        )
      end

      items = @cluster_repository.find_items(id)

      story_responses = items.map do |story|
        Quickheadlines::DTOs::StoryResponse.from_entity(story)
      end

      ClusterItemsResult.new(
        cluster_id: cluster_id,
        items: story_responses
      )
    end
  end

  struct TimelineResult
    property items : Array(TimelineItemResponse)
    property has_more : Bool
    property total_count : Int32

    def initialize(@items, @has_more, @total_count)
    end
  end

  struct ClustersResult
    property clusters : Array(Quickheadlines::DTOs::ClusterResponse)
    property total_count : Int32

    def initialize(@clusters, @total_count)
    end
  end

  struct ClusterItemsResult
    property cluster_id : String
    property items : Array(Quickheadlines::DTOs::StoryResponse)

    def initialize(@cluster_id, @items)
    end
  end
end
