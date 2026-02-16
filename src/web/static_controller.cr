require "athena"
require "./assets"

class StaticController < Athena::Framework::Controller
  private def get_mime_type(path : String) : String
    ext = path.split(".").last?.try(&.downcase) || ""
    case ext
    when "js"            then "application/javascript; charset=utf-8"
    when "css"           then "text/css; charset=utf-8"
    when "html"          then "text/html; charset=utf-8"
    when "svg"           then "image/svg+xml"
    when "png"           then "image/png"
    when "jpg", "jpeg"   then "image/jpeg"
    when "ico"           then "image/x-icon"
    when "woff", "woff2" then "font/woff2"
    when "json"          then "application/json"
    else                      "application/octet-stream"
    end
  end

  private def serve_asset(path : String) : ATH::Response
    file = FrontendAssets.get(path)
    content = file.gets_to_end
    mime = get_mime_type(path)

    response = ATH::Response.new(content)
    response.headers["Content-Type"] = mime

    if ENV["APP_ENV"]? == "development"
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    else
      if path.includes?("_app/immutable/")
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

  @[ARTA::Get(path: "/favicon.svg")]
  def favicon_svg : ATH::Response
    serve_asset("favicon.svg")
  end

  @[ARTA::Get(path: "/favicon.ico")]
  def favicon_ico : ATH::Response
    file = FrontendAssets.get("favicon.svg")
    content = file.gets_to_end

    response = ATH::Response.new(content)
    response.headers["Content-Type"] = "image/svg+xml"

    if ENV["APP_ENV"]? == "development"
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    else
      response.headers["Cache-Control"] = "public, max-age=3600"
    end

    response
  rescue ex : BakedFileSystem::NoSuchFileError
    ATH::Response.new("Not Found: favicon.ico", 404, HTTP::Headers{"Content-Type" => "text/plain"})
  rescue ex
    ATH::Response.new("Error: #{ex.message}", 500, HTTP::Headers{"Content-Type" => "text/plain"})
  end

  @[ARTA::Get(path: "/logo.svg")]
  def logo_svg : ATH::Response
    serve_asset("logo.svg")
  end

  @[ARTA::Get(path: "/fonts/Inter-Variable.woff2")]
  def fonts_inter : ATH::Response
    serve_asset("fonts/Inter-Variable.woff2")
  end

  @[ARTA::Get(path: "/_app/immutable/{folder}/{filename}", requirements: {"folder" => /\w+/, "filename" => /.+/})]
  def app_immutable_assets(folder : String, filename : String) : ATH::Response
    serve_asset("_app/immutable/#{folder}/#{filename}")
  end

  @[ARTA::Get(path: "/_app/{filename}", requirements: {"filename" => /[^\/]+/})]
  def app_root_assets(filename : String) : ATH::Response
    serve_asset("_app/#{filename}")
  end
end
