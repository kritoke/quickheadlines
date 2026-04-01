require "./api_base_controller"
require "../web/assets"

class QuickHeadlines::Controllers::AssetController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/favicon.png")]
  def favicon_png(request : ATH::Request) : ATH::Response
    url = request.query_params["url"]?

    if url.nil? || url.strip.empty?
      return ATH::Response.new("Missing 'url' parameter", 400, HTTP::Headers{"content-type" => "text/plain"})
    end

    normalized_url = normalize_url(url)

    if favicon_path = FaviconStorage.get_or_fetch(normalized_url)
      if File.exists?(favicon_path)
        content = File.read(favicon_path)
        mime_type = case favicon_path
                    when /\.png$/ then "image/png"
                    when /\.ico$/ then "image/x-icon"
                    when /\.svg$/ then "image/svg+xml"
                    when /\.gif$/ then "image/gif"
                    when /\.jpg$/, /\.jpeg$/ then "image/jpeg"
                    else "application/octet-stream"
                    end
        return ATH::Response.new(content, 200, HTTP::Headers{"content-type" => mime_type})
      end
    end

    ATH::Response.new("Favicon not found", 404, HTTP::Headers{"content-type" => "text/plain"})
  end

  @[ARTA::Get(path: "/api/sun-icon.svg")]
  def sun_icon_svg : ATH::Response
    content = FrontendAssets.get("sun-icon.svg").gets_to_end
    ATH::Response.new(content, 200, HTTP::Headers{"content-type" => "image/svg+xml"})
  end

  @[ARTA::Get(path: "/api/moon-icon.svg")]
  def moon_icon_svg : ATH::Response
    content = FrontendAssets.get("moon-icon.svg").gets_to_end
    ATH::Response.new(content, 200, HTTP::Headers{"content-type" => "image/svg+xml"})
  end

  @[ARTA::Get(path: "/api/home-icon.svg")]
  def home_icon_svg : ATH::Response
    content = FrontendAssets.get("home-icon.svg").gets_to_end
    ATH::Response.new(content, 200, HTTP::Headers{"content-type" => "image/svg+xml"})
  end

  @[ARTA::Get(path: "/api/timeline-icon.svg")]
  def timeline_icon_svg : ATH::Response
    content = FrontendAssets.get("timeline-icon.svg").gets_to_end
    ATH::Response.new(content, 200, HTTP::Headers{"content-type" => "image/svg+xml"})
  end
end