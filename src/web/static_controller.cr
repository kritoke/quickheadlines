require "athena"
require "./assets"

class StaticController < Athena::Framework::Controller
  private def get_mime_type(path : String) : String
    ext = path.split(".").last?.try(&.downcase) || ""
    case ext
    when "js"   then "application/javascript; charset=utf-8"
    when "css"  then "text/css; charset=utf-8"
    when "html" then "text/html; charset=utf-8"
    when "svg"  then "image/svg+xml"
    when "png"  then "image/png"
    when "jpg", "jpeg" then "image/jpeg"
    when "ico"  then "image/x-icon"
    when "woff", "woff2" then "font/woff2"
    when "json" then "application/json"
    else "application/octet-stream"
    end
  end

  private def serve_asset(path : String) : ATH::Response
    begin
      file = FrontendAssets.get(path)
      content = file.gets_to_end
      mime = get_mime_type(path)
      
      response = ATH::Response.new(content)
      response.headers["Content-Type"] = mime
      
      if ENV["APP_ENV"]? == "development"
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      else
        if path.includes?("/_app/immutable/")
          response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        else
          response.headers["Cache-Control"] = "public, max-age=3600"
        end
      end
      
      response
    rescue ex : BakedFileSystem::NoSuchFileError
      ATH::Response.new("Not Found: #{path}", 404, HTTP::Headers{"Content-Type" => "text/plain"})
    rescue ex
      ATH::Response.new("Error: #{ex.message}", 500, HTTP::Headers{"Content-Type" => "text/plain"})
    end
  end

  @[ARTA::Get(path: "/")]
  def index : ATH::Response
    serve_asset("index.html")
  end

  @[ARTA::Get(path: "/timeline")]
  def timeline : ATH::Response
    serve_asset("timeline.html")
  end

  @[ARTA::Get(path: "/timeline/")]
  def timeline_slash : ATH::Response
    serve_asset("timeline.html")
  end

  @[ARTA::Get(path: "/_app/{path*}")]
  def app_assets(path : String) : ATH::Response
    serve_asset("_app/#{path}")
  end

  @[ARTA::Get(path: "/favicon.svg")]
  def favicon_svg : ATH::Response
    serve_asset("favicon.svg")
  end

  @[ARTA::Get(path: "/favicon.ico")]
  def favicon_ico : ATH::Response
    serve_asset("favicon.svg")
  end

  @[ARTA::Get(path: "/fonts/{path*}")]
  def fonts(path : String) : ATH::Response
    serve_asset("fonts/#{path}")
  end
end
