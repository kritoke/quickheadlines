require "./api_base_controller"

class QuickHeadlines::Controllers::HeaderColorController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Post(path: "/api/header_color")]
  def save_header_color(request : ATH::Request) : QuickHeadlines::DTOs::HeaderColorResponse
    raise ATH::Exception::HTTPException.new(401, "Unauthorized") unless check_admin_auth(request)

    body_io = request.body
    raise ATH::Exception::BadRequest.new("Missing request body") if body_io.nil?

    body = JSON.parse(read_body_safe(body_io))
    feed_url, color, text_color = parse_color_params(body)

    raise ATH::Exception::BadRequest.new("Missing feed_url, color, or text_color") unless feed_url && color && text_color

    config = StateStore.config
    raise ATH::Exception::ServiceUnavailable.new("Configuration not loaded") if config.nil?

    if has_manual_color_override?(config, feed_url)
      return QuickHeadlines::DTOs::HeaderColorResponse.new(status: "skipped")
    end

    normalized_url = feed_url.strip.rstrip('/').gsub(/\/rss(\.xml)?$/i, "")
    cache = @feed_cache
    db_url = cache.find_url_by_pattern(normalized_url) || feed_url

    cache.update_header_colors(db_url, color, text_color)
    QuickHeadlines::DTOs::HeaderColorResponse.new(status: "ok")
  rescue ex : ATH::Exception::HTTPException
    raise ex
  rescue IO::EOFError
    raise ATH::Exception::HTTPException.new(413, "Request body too large")
  rescue ex
    Log.for("quickheadlines.http").error(exception: ex) { "Header color save error" }
    raise ATH::Exception::HTTPException.new(500, "Internal server error")
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

  private def has_manual_color_override?(config : Config, feed_url : String) : Bool
    config.tabs.any? do |tab|
      tab.feeds.any? do |feed|
        feed.url == feed_url && !feed.header_color.nil?
      end
    end
  end
end
