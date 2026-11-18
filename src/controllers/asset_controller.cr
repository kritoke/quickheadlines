require "./api_base_controller"
require "../web/assets"

class QuickHeadlines::Controllers::AssetController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/favicon.png")]
  def favicon_png(request : AHTTP::Request) : AHTTP::Response
    check_rate_limit!(request, "api_favicon", 120, 60)

    url = request.query_params["url"]?

    raise AHK::Exception::BadRequest.new("Missing 'url' parameter") if url.nil? || url.strip.empty?

    normalized_url = QuickHeadlines::CacheUtils.normalize_feed_url(url)

    # get_or_fetch returns a URL path ("/favicons/<hash>.<ext>"), not a
    # filesystem path; map its basename into the favicon directory.
    if favicon_url = @favicon_actor.get_or_fetch(normalized_url)
      name = File.basename(favicon_url)
      if name.matches?(/\A[a-f0-9]{16}\.(png|ico|svg|gif|jpg|jpeg|webp)\z/)
        favicon_path = File.join(FaviconActor.favicon_dir, name)
        if File.exists?(favicon_path)
          content = ::Utils.read_binary_file(favicon_path)
          return AHTTP::Response.new(content, 200, HTTP::Headers{
            "content-type"           => ::Utils.mime_type_from_path(favicon_path),
            "cache-control"          => "public, max-age=86400",
            "x-content-type-options" => "nosniff",
          })
        end
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
