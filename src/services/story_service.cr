require "../repositories/story_repository"
require "../dtos/api_responses"

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
        TimelineItemResponse.new(
          id: item.id.to_s,
          title: item.title,
          link: item.link,
          pub_date: item.pub_date.try(&.to_unix_ms),
          feed_title: item.feed_title,
          feed_url: item.feed_url,
          feed_link: item.feed_link,
          favicon: item.favicon,
          favicon_data: item.favicon_data,
          header_color: item.header_color,
          header_text_color: item.header_text_color,
          cluster_id: item.cluster_id.try(&.to_s),
          is_representative: item.representative,
          cluster_size: item.cluster_size,
          comment_url: item.comment_url,
          commentary_url: item.commentary_url
        )
      end

      TimelineResult.new(
        items: timeline_items,
        has_more: has_more,
        total_count: total_count
      )
    end
  end

  struct TimelineResult
    property items : Array(TimelineItemResponse)
    getter? has_more : Bool
    property total_count : Int32

    def initialize(@items, @has_more, @total_count)
    end
  end
end
