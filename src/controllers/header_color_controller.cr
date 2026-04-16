require "./api_base_controller"

class QuickHeadlines::Controllers::HeaderColorController < QuickHeadlines::Controllers::ApiBaseController
  private JSON_CT = HTTP::Headers{"content-type" => "application/json"}
  private TEXT_CT = HTTP::Headers{"content-type" => "text/plain"}

  @[ARTA::Post(path: "/api/header_color")]
  def save_header_color(request : ATH::Request) : ATH::Response
    unless check_admin_auth(request)
      return unauthorized_response
    end

    body_io = request.body
    return ATH::Response.new("{\"error\": \"Missing request body\"}", 400, JSON_CT) if body_io.nil?

    body = JSON.parse(read_body_safe(body_io))
    feed_url, color, text_color = parse_color_params(body)

    unless feed_url && color && text_color
      return ATH::Response.new("{\"error\": \"Missing feed_url, color, or text_color\"}", 400, JSON_CT)
    end

    config = StateStore.config
    return ATH::Response.new("{\"error\": \"Configuration not loaded\"}", 503, JSON_CT) if config.nil?

    if has_manual_color_override?(config, feed_url)
      return ATH::Response.new("{\"error\": \"Skipped: manual config exists\"}", 200, JSON_CT)
    end

    normalized_url = feed_url.strip.rstrip('/').gsub(/\/rss(\.xml)?$/i, "")
    cache = @feed_cache
    db_url = cache.find_url_by_pattern(normalized_url) || feed_url

    cache.update_header_colors(db_url, color, text_color)
    ATH::Response.new("{\"status\": \"ok\"}", 200, JSON_CT)
  rescue IO::EOFError
    ATH::Response.new("{\"error\": \"Request body too large\"}", 413, JSON_CT)
  rescue ex
    Log.for("quickheadlines.http").error(exception: ex) { "Header color save error" }
    ATH::Response.new("{\"error\": \"Internal server error\"}", 500, JSON_CT)
  end

  private def present?(value : String?) : Bool
    !value.nil? && !value.strip.empty?
  end

  private def parse_color_params(body : JSON::Any) : Tuple(String?, String?, String?)
    feed_url = body["feed_url"]?.try(&.as_s?)
    color = body["color"]?.try(&.as_s?)
    text_color = body["text_color"]?.try(&.as_s?)

    if present?(feed_url) && present?(color) && present?(text_color)
      return {feed_url, color, text_color}
    end
    {nil, nil, nil}
  end

  private def has_manual_color_override?(config, feed_url) : Bool
    config.tabs.any? do |tab|
      tab.feeds.any? do |feed|
        feed.url == feed_url && !feed.header_color.nil?
      end
    end
  end
end
