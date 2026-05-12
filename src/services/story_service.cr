require "../repositories/story_repository"
require "../dtos/api_responses"
require "../dtos/story_dto"

module QuickHeadlines::Services
  module StoryService
    def self.get_timeline(
      story_repo : QuickHeadlines::Repositories::StoryRepository,
      limit : Int32,
      offset : Int32,
      days : Int32?,
      allowed_feed_urls : Array(String) = [] of String,
    ) : TimelineResult
      items = story_repo.find_timeline_items(limit, offset, days, allowed_feed_urls)
      total_count = story_repo.count_timeline_items(days, allowed_feed_urls)
      has_more = offset + limit < total_count

      timeline_items = items.map do |item|
        QuickHeadlines::DTOs::StoryResponse.from_timeline_item(item)
      end

      TimelineResult.new(
        items: timeline_items,
        has_more: has_more,
        total_count: total_count
      )
    end
  end

  struct TimelineResult
    property items : Array(QuickHeadlines::DTOs::TimelineItemResponse)
    getter? has_more : Bool
    property total_count : Int32

    def initialize(@items, @has_more, @total_count)
    end
  end
end
