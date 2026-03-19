require "../repositories/story_repository"
require "../repositories/cluster_repository"
require "../dtos/story_dto"
require "../dtos/cluster_dto"
require "../api"

module Quickheadlines::Services
  module StoryService
    def self.get_timeline(
      story_repo : Quickheadlines::Repositories::StoryRepository,
      limit : Int32,
      offset : Int32,
      days : Int32?,
      cursor : String? = nil,
      feed_urls : Array(String)? = nil,
    ) : TimelineResult
      items = story_repo.find_timeline_items(limit + 1, offset, days, cursor, feed_urls)
      total_count = story_repo.count_timeline_items(days, cursor, feed_urls)
      has_more = items.size > limit

      if has_more
        items = items[0...limit]
      end

      next_cursor = if has_more && (last_item = items.last)
                      last_item.pub_date.try(&.to_unix_ms).try(&.to_s)
                    end

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
          is_representative: item.representative?,
          cluster_size: item.cluster_size
        )
      end

      TimelineResult.new(
        items: timeline_items,
        has_more: has_more,
        total_count: total_count,
        cursor: next_cursor
      )
    end

    def self.get_clusters(cluster_repo : Quickheadlines::Repositories::ClusterRepository) : ClustersResult
      clusters = cluster_repo.find_all

      cluster_responses = clusters.map do |cluster|
        Quickheadlines::DTOs::ClusterResponse.from_entity(cluster)
      end

      ClustersResult.new(
        clusters: cluster_responses,
        total_count: cluster_responses.size
      )
    end

    def self.get_cluster_items(cluster_repo : Quickheadlines::Repositories::ClusterRepository, cluster_id : String) : ClusterItemsResult
      id = cluster_id.to_i64?

      if id.nil?
        return ClusterItemsResult.new(
          cluster_id: cluster_id,
          items: [] of Quickheadlines::DTOs::StoryResponse
        )
      end

      items = cluster_repo.find_items(id)

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
    getter? has_more : Bool
    property total_count : Int32
    property cursor : String? = nil

    def initialize(@items, @has_more, @total_count, @cursor = nil)
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
