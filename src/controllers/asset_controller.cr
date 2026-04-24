require "./api_base_controller"
require "../web/assets"

class QuickHeadlines::Controllers::AssetController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/favicon.png")]
  def favicon_png(request : AHTTP::Request) : AHTTP::Response
    check_rate_limit!(request, "api_favicon", 120, 60)

    url = request.query_params["url"]?

    raise AHK::Exception::BadRequest.new("Missing 'url' parameter") if url.nil? || url.strip.empty?

    normalized_url = normalize_feed_url(url)

    if favicon_path = FaviconStorage.get_or_fetch(normalized_url)
      if File.exists?(favicon_path)
        content = File.read(favicon_path)
        return AHTTP::Response.new(content, 200, HTTP::Headers{"content-type" => mime_type_from_path(favicon_path)})
      end
    end

    raise AHK::Exception::NotFound.new("Favicon not found")
  end

  private def serve_icon(name : String) : AHTTP::Response
    content = FrontendAssets.get("#{name}.svg").gets_to_end
    AHTTP::Response.new(content, 200, HTTP::Headers{"content-type" => "image/svg+xml"})
  end

  @[ARTA::Get(path: "/api/sun-icon.svg")]
  def sun_icon_svg : AHTTP::Response
    serve_icon("sun-icon")
  end

  @[ARTA::Get(path: "/api/moon-icon.svg")]
  def moon_icon_svg : AHTTP::Response
    serve_icon("moon-icon")
  end

  @[ARTA::Get(path: "/api/home-icon.svg")]
  def home_icon_svg : AHTTP::Response
    serve_icon("home-icon")
  end

  @[ARTA::Get(path: "/api/timeline-icon.svg")]
  def timeline_icon_svg : AHTTP::Response
    serve_icon("timeline-icon")
  end
end
