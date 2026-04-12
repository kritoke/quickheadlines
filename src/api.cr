require "json"
require "./models"
require "./dtos/api_responses"

module Api
  def self.feed_to_response(feed : FeedData, tab_name : String = "", total_count : Int32? = nil, display_item_limit : Int32? = nil) : FeedResponse
    cache = FeedCache.instance

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

    limit = display_item_limit || 20

    displayed_items = feed.items.first(limit)

    items_response = displayed_items.map do |item|
      ItemResponse.new(
        title: item.title,
        link: item.link,
        version: item.version,
        pub_date: item.pub_date.try(&.to_unix_ms),
        comment_url: item.comment_url,
        commentary_url: item.commentary_url
      )
    end

    FeedResponse.new(
      tab: tab_name,
      url: feed.url,
      title: feed.title,
      site_link: feed.site_link,
      display_link: feed.display_link,
      favicon: feed.favicon,
      favicon_data: feed.favicon_data,
      header_color: header_color,
      header_text_color: header_text_color,
      header_theme_colors: begin
        header_theme_colors_json ? JSON.parse(header_theme_colors_json) : nil
      rescue JSON::ParseException
        nil
      end,
      items: items_response,
      total_item_count: total_count || feed.items.size.to_i32
    )
  end
end
