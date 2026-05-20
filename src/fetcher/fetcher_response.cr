require "fetcher"
require "../models"
require "../color_extractor"
require "./theme_helper"
require "./software_util"

# Response handling logic extracted from FeedFetcher.
# Converts raw fetch results into FeedData, handles success/error paths,
# and manages content storage.
module FetcherResponse
  include Fetcher::ThemeHelper

  # Process a successful fetch result into a FeedData with favicons and theme colors.
  # Content is persisted to the Azurite DB first, then stripped from in-memory items
  # to reduce memory usage. Content is fetched on-demand via ContentService.
  def handle_success(result, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?) : FeedData
    Log.for("quickheadlines.feed").debug { "handle_success: #{feed.url} - result.entries.size=#{result.entries.size}, effective_item_limit=#{effective_item_limit}" }

    if result.entries.empty?
      Log.for("quickheadlines.feed").debug { "Feed returned no items: #{feed.title} (#{feed.url})" }
      return build_error_feed(feed, "No items found (or unsupported format)")
    end

    # Persist content to DB BEFORE stripping it from items
    persist_entry_content(result.entries, feed.url)

    # Build items WITHOUT content to save memory (~20-50KB per article)
    items = entries_to_items(result.entries, strip_content: true)
    Log.for("quickheadlines.feed").debug { "handle_success: #{feed.url} - items.size=#{items.size}" }

    site_link = result.site_link || feed.url
    favicon, favicon_data = resolve_favicons(site_link, feed, result.favicon, previous_data)

    # Clear favicon_data from memory after it's been saved to disk by resolve_favicons
    # The favicon is served via /favicons/{hash}.png, not from memory
    favicon_path = favicon_data || (favicon && favicon.starts_with?("/favicons/") ? favicon : nil)

    local_favicon_path = favicon_path
    header_color, header_text_color, header_theme_json = extract_header_colors(feed, local_favicon_path)
    final_header_color, final_text_color = parse_legacy_theme(header_color, header_text_color, header_theme_json)

    preserved_header_color = final_header_color || previous_data.try(&.header_color)
    preserved_text_color = final_text_color || previous_data.try(&.header_text_color)
    preserved_theme = header_theme_json || previous_data.try(&.header_theme_colors)

    feed_data = FeedData.new(
      feed.title,
      feed.url,
      site_link,
      preserved_header_color,
      preserved_text_color,
      items,
      result.etag,
      result.last_modified,
      favicon_path,
      nil # favicon_data cleared — served from disk via /favicons/ route
    )

    feed_data = feed_data.with_theme_colors(preserved_theme) if preserved_theme

    cache.add(feed_data)

    if final_result = process_response_result(feed_data, feed, effective_item_limit, previous_data)
      return final_result
    end
    feed_data
  end

  # Handle a failed fetch result — try stale cache, then error feed.
  def handle_error(result, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?) : FeedData
    error_msg = result.error_message || "Unknown error"
    Log.for("quickheadlines.feed").warn { "fetch_feed(#{feed.url}) error: #{error_msg}" }
    if stale_cache = get_stale_cached_feed(feed, effective_item_limit, previous_data)
      return stale_cache
    end
    build_error_feed(feed, "Error: #{error_msg}")
  end

  # Build an error feed placeholder for failed fetches.
  # Skips VugAdapter to avoid DNS hangs on error paths.
  def build_error_feed(feed : Feed, message : String) : FeedData
    site_link = feed.url

    Log.for("quickheadlines.feed").warn { "[FEED ERROR] #{feed.title} (#{feed.url}) - #{message}" }

    favicon = VugAdapter.google_favicon_url(site_link.presence || feed.url)
    favicon_data = nil

    header_color, header_text_color = extract_header_colors(feed, favicon_data)

    FeedData.new(
      title: feed.title,
      url: feed.url,
      site_link: site_link,
      header_color: header_color,
      header_text_color: header_text_color,
      items: [Item.new(message, feed.url, nil, nil, nil, nil)],
      etag: nil,
      last_modified: nil,
      favicon: favicon,
      favicon_data: favicon_data,
      error_message: message,
      header_theme_colors: nil,
    )
  end

  # Convert fetcher entries to sorted Item array.
  # Content is stored to the DB separately and stripped from in-memory items
  # to reduce memory usage. Content is fetched on-demand via ContentService.
  private def entries_to_items(entries : Array(Fetcher::Entry), strip_content : Bool = false) : Array(Item)
    entries.map do |entry|
      comment_url = entry.comment_url || (entry.is_discussion_url ? entry.url : nil)
      Item.new(entry.title, entry.url, entry.published_at, strip_content ? nil : entry.content, comment_url, entry.commentary_url)
    end.sort_by! { |item| item.pub_date || Time.unix(0) }.reverse!
  end

  # Persist entry content to the Azurite DB directly from raw entries.
  # This is done BEFORE creating Item objects so we can strip content from memory.
  private def persist_entry_content(entries : Array(Fetcher::Entry), feed_url : String) : Nil
    has_content = entries.any?(&.content.presence)
    return unless has_content

    begin
      content_service = QuickHeadlines::Services::ContentService.instance
    rescue
      return
    end

    entries.each do |entry|
      if content = entry.content.presence
        content_service.store_content(entry.url, feed_url, entry.title, content)
      end
    end
  rescue ex
    Log.for("quickheadlines.feed").debug { "Content storage skipped: #{ex.message}" }
  end

  # If the response is actually an error feed, try stale cache fallback.
  private def process_response_result(result_data : FeedData, feed : Feed, effective_item_limit : Int32, previous_data : FeedData?) : FeedData?
    if stale_cache_fallback?(result_data, feed)
      get_stale_cached_feed(feed, effective_item_limit, previous_data) || result_data
    else
      result_data
    end
  end

  # Build software release feeds for a tab.
  private def build_software_releases(software_config : SoftwareConfig?, item_limit : Int32) : Array(FeedData)
    QuickHeadlines::SoftwareUtil.build_software_releases(software_config, item_limit)
  end
end
