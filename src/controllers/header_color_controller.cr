require "./api_base_controller"

class QuickHeadlines::Controllers::HeaderColorController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Post(path: "/api/header_color")]
  def save_header_color(request : ATH::Request) : ATH::Response
    body_io = request.body
    return ATH::Response.new("Missing request body", 400) if body_io.nil?

    body = JSON.parse(read_body_safe(body_io))
    feed_url = body["feed_url"]?.try(&.as_s?)
    color = body["color"]?.try(&.as_s?)
    text_color = body["text_color"]?.try(&.as_s?)

    if feed_url.nil? || color.nil? || text_color.nil? ||
       feed_url.strip.empty? || color.empty? || text_color.empty?
      return ATH::Response.new("Missing feed_url, color, or text_color", 400)
    end

    config = StateStore.config
    return ATH::Response.new("Configuration not loaded", 500) if config.nil?

    if has_manual_color_override?(config, feed_url)
      return ATH::Response.new("Skipped: manual config exists", 200)
    end

    normalized_url = feed_url.strip.rstrip('/').gsub(/\/rss(\.xml)?$/i, "")
    cache = @feed_cache
    db_url = cache.find_feed_url_by_pattern(normalized_url) || feed_url

    cache.update_header_colors(db_url, color, text_color)
    ATH::Response.new("OK", 200)
  rescue ex : IO::EOFError
    ATH::Response.new("Request body too large", 413, HTTP::Headers{"content-type" => "text/plain"})
  rescue ex
    Log.for("quickheadlines.http").error(exception: ex) { "Header color save error" }
    ATH::Response.new("Internal server error", 500)
  end

  private def has_manual_color_override?(config, feed_url) : Bool
    config.tabs.any? do |tab|
      tab.feeds.any? do |feed|
        feed.url == feed_url && !feed.header_color.nil?
      end
    end
  end
end
