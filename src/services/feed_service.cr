require "json"
require "../models"
require "../dtos/api_responses"
require "../storage/feed_cache"
require "azurite"

module QuickHeadlines::Services
  module FeedService
    @@content_store : Azurite::Store?

    def self.content_store=(store : Azurite::Store)
      @@content_store = store
    end

    def self.content_store
      @@content_store
    end

    def self.build_feed_response(
      feed : FeedData,
      cache : FeedCache,
      tab_name : String = "",
      total_count : Int32? = nil,
      display_item_limit : Int32? = nil,
    ) : QuickHeadlines::DTOs::FeedResponse
      header_color = feed.header_color
      header_text_color = feed.header_text_color

      header_theme_colors_json = nil.as(String?)
      if header_color.nil? || header_text_color.nil?
        colors = cache.get_header_colors(feed.url)
        header_color ||= colors[:bg_color]
        header_text_color ||= colors[:text_color]
      end

      begin
        theme_json = cache.load_theme(feed.url)
        header_theme_colors_json = theme_json if theme_json && !theme_json.empty?
      rescue DB::Error | JSON::ParseException
        header_theme_colors_json = nil
      end

      build_response_for_feed(feed, cache, tab_name, total_count, display_item_limit, header_color, header_text_color, header_theme_colors_json)
    end

    private def self.build_response_for_feed(
      feed : FeedData,
      cache : FeedCache,
      tab_name : String,
      total_count : Int32?,
      display_item_limit : Int32?,
      header_color : String?,
      header_text_color : String?,
      header_theme_colors_json : String?,
    ) : QuickHeadlines::DTOs::FeedResponse
      limit = display_item_limit || 20
      displayed_items = feed.items.first(limit)

      items_response = map_items_to_responses(displayed_items, cache)

      QuickHeadlines::DTOs::FeedResponse.new(
        tab: tab_name,
        url: feed.url,
        title: feed.title,
        site_link: feed.site_link,
        display_link: feed.display_link,
        favicon: feed.favicon,
        favicon_data: feed.favicon_data,
        header_color: header_color,
        header_text_color: header_text_color,
        header_theme_colors: parse_theme_colors(header_theme_colors_json),
        items: items_response,
        total_item_count: total_count || feed.items.size.to_i32,
      )
    end

    private def self.map_items_to_responses(items : Array(Item), cache : FeedCache) : Array(QuickHeadlines::DTOs::ItemResponse)
      items.map do |item|
        stored_content = item.content || @@content_store.try(&.get_content(item.link))
        QuickHeadlines::DTOs::ItemResponse.new(
          title: item.title,
          link: item.link,
          content: stored_content,
          version: item.version,
          pub_date: item.pub_date.try(&.to_unix_ms),
          comment_url: item.comment_url,
          commentary_url: item.commentary_url,
        )
      end
    end

    private def self.parse_theme_colors(json : String?) : JSON::Any?
      return unless json
      JSON.parse(json)
    rescue JSON::ParseException
    end

    def self.build_feed_more_response(
      feed : FeedData,
      tab_name : String,
      offset : Int32,
      limit : Int32,
      cache : FeedCache,
      item_count : Int32,
    ) : QuickHeadlines::DTOs::FeedResponse
      trimmed_items = feed.items[offset...Math.min(offset + limit, feed.items.size)]
      items_response = map_items_to_responses(trimmed_items, cache)

      # Resolve header colors with fallback to cache
      header_color = feed.header_color
      header_text_color = feed.header_text_color
      if header_color.nil? || header_text_color.nil?
        colors = cache.get_header_colors(feed.url)
        header_color ||= colors[:bg_color]
        header_text_color ||= colors[:text_color]
      end

      header_theme_colors_json = nil.as(String?)
      begin
        theme_json = cache.load_theme(feed.url)
        header_theme_colors_json = theme_json if theme_json && !theme_json.empty?
      rescue DB::Error | JSON::ParseException
        header_theme_colors_json = nil
      end

      QuickHeadlines::DTOs::FeedResponse.new(
        tab: tab_name,
        url: feed.url,
        title: feed.title,
        site_link: feed.site_link,
        display_link: feed.display_link,
        favicon: feed.favicon,
        favicon_data: feed.favicon_data,
        header_color: header_color,
        header_text_color: header_text_color,
        header_theme_colors: parse_theme_colors(header_theme_colors_json),
        items: items_response,
        total_item_count: item_count,
      )
    end

    # Collect {feed, tab_name} pairs for the active tab (or all tabs).
    private def self.collect_feed_pairs(
      feeds_snapshot : Array(FeedData),
      tabs_snapshot : Array(Tab),
      active_tab : String,
    ) : Array({feed: FeedData, tab_name: String})
      is_all = active_tab.to_s.downcase == "all"
      pairs = [] of {feed: FeedData, tab_name: String}

      if is_all
        feeds_snapshot.each { |feed| pairs << {feed: feed, tab_name: ""} unless feed.failed? }
        tabs_snapshot.each do |tab|
          tab.feeds.each { |feed| pairs << {feed: feed, tab_name: tab.name} unless feed.failed? }
        end
      else
        matched_tab = tabs_snapshot.find { |tab| tab.name.downcase == active_tab.downcase }
        matched_tab.try(&.feeds.each { |feed| pairs << {feed: feed, tab_name: active_tab} unless feed.failed? })
      end

      pairs
    end

    # Collect software release feeds for the active tab.
    private def self.collect_software_releases(
      tabs_snapshot : Array(Tab),
      active_tab : String,
    ) : Array(FeedData)
      return [] of FeedData if active_tab.to_s.downcase == "all"

      matched_tab = tabs_snapshot.find { |tab| tab.name.downcase == active_tab.downcase }
      matched_tab.try(&.software_releases) || [] of FeedData
    end

    def self.build_feeds_page(
      feeds_snapshot : Array(FeedData),
      tabs_snapshot : Array(Tab),
      active_tab : String,
      is_clustering : Bool,
      cache : FeedCache,
      item_limit : Int32,
    ) : QuickHeadlines::DTOs::FeedsPageResponse
      tabs_response = tabs_snapshot.map { |tab| QuickHeadlines::DTOs::TabResponse.new(name: tab.name) }

      feed_pairs = collect_feed_pairs(feeds_snapshot, tabs_snapshot, active_tab)
      all_urls = feed_pairs.map { |pair| pair[:feed].url }
      item_counts = cache.item_counts(all_urls)

      feeds_response = feed_pairs.map do |entry|
        build_feed_response(entry[:feed], cache, tab_name: entry[:tab_name], total_count: item_counts[entry[:feed].url]? || 0, display_item_limit: item_limit)
      end

      software_releases = collect_software_releases(tabs_snapshot, active_tab)
      software_releases_response = software_releases.map do |feed|
        build_feed_response(feed, cache, tab_name: active_tab, total_count: item_counts[feed.url]? || 0, display_item_limit: item_limit)
      end

      QuickHeadlines::DTOs::FeedsPageResponse.new(
        tabs: tabs_response,
        active_tab: active_tab.to_s,
        feeds: feeds_response,
        software_releases: software_releases_response,
        clustering: is_clustering,
        updated_at: StateStore.updated_at.to_unix_ms,
      )
    end
  end
end
