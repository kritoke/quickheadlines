require "../repositories/feed_repository"

module Quickheadlines::Services
  class FeedService
    @feed_repository : Quickheadlines::Repositories::FeedRepository

    def initialize(@feed_repository : Quickheadlines::Repositories::FeedRepository)
    end

    def get_all_feeds : Array(Quickheadlines::Entities::Feed)
      @feed_repository.find_all
    end

    def get_feed_with_items(url : String, limit : Int32 = 20) : FeedWithItems?
      feed = @feed_repository.find_by_url(url)
      return nil unless feed

      items = [] of Item

      {url: url, title: feed.title, site_link: feed.site_link, header_color: feed.header_color, header_text_color: feed.header_text_color, favicon: feed.favicon, favicon_data: feed.favicon_data, items: items}
    end

    def update_feed_colors(url : String, bg : String, text : String) : Void
      @feed_repository.update_header_colors(url, bg, text)
    end

    def cleanup_orphaned_feeds(config_urls : Set(String)) : CleanupResult
      existing_feeds = @feed_repository.find_all
      orphaned = existing_feeds.reject { |feed| config_urls.includes?(feed.url) }

      deleted_count = 0
      deleted_items = 0

      orphaned.each do |feed|
        item_count = @feed_repository.count_items(feed.url)
        @feed_repository.delete_by_url(feed.url)
        deleted_count += 1
        deleted_items += item_count
      end

      CleanupResult.new(
        feeds_deleted: deleted_count,
        items_deleted: deleted_items
      )
    end
  end

  struct FeedWithItems
    property url : String
    property title : String
    property site_link : String
    property header_color : String?
    property header_text_color : String?
    property favicon : String?
    property favicon_data : String?
    property items : Array(Item)

    def initialize(@url, @title, @site_link, @header_color, @header_text_color, @favicon, @favicon_data, @items)
    end
  end

  struct Item
    property title : String
    property link : String
    property pub_date : Time?
    property version : String?

    def initialize(@title, @link, @pub_date, @version)
    end
  end

  struct CleanupResult
    property feeds_deleted : Int32
    property items_deleted : Int32

    def initialize(@feeds_deleted, @items_deleted)
    end
  end
end
