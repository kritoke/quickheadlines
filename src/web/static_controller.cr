require "athena"
require "./assets"
require "../favicon_storage"
require "../utils"

class StaticController < Athena::Framework::Controller
  private def apply_security_headers(response : ATH::Response, mime : String) : Nil
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"

    if mime.starts_with?("text/html")
      csp = "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; " \
            "img-src 'self' https:; script-src 'self' 'unsafe-inline'; " \
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " \
            "connect-src 'self' ws: wss:; font-src 'self' https://fonts.googleapis.com https://fonts.gstatic.com; " \
            "frame-src 'none'"
      response.headers["Content-Security-Policy"] = csp
    end
  end

  private def serve_asset(path : String) : ATH::Response
    file = FrontendAssets.get(path)
    content = file.gets_to_end
    mime = mime_type_from_path(path)

    response = ATH::Response.new(content)
    response.headers["content-type"] = mime

    if ENV["APP_ENV"]? == "development"
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    else
      if path.includes?("_app/immutable/")
        response.headers["Cache-Control"] = "public, max-age=#{QuickHeadlines::Constants::CACHE_ONE_YEAR}, immutable"
      else
        response.headers["Cache-Control"] = "public, max-age=#{QuickHeadlines::Constants::CACHE_ONE_HOUR}"
      end
    end

    apply_security_headers(response, mime)

    response
  rescue BakedFileSystem::NoSuchFileError
    ATH::Response.new("Not Found", 404, HTTP::Headers{"content-type" => "text/plain"})
  rescue ex
    Log.for("quickheadlines.http").error(exception: ex) { "Static file error for #{path}" }
    ATH::Response.new("Internal server error", 500, HTTP::Headers{"content-type" => "text/plain"})
  end

  @[ARTA::Get(path: "/")]
  def index : ATH::Response
    serve_asset("index.html")
  end

  @[ARTA::Get(path: "/health")]
  def health : ATH::Response
    response = ATH::Response.new(%({"status": "ok", "time": #{Time.utc.to_unix_ms}}))
    response.headers["content-type"] = "application/json"
    response
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
    serve_asset("favicon.svg")
  end

  @[ARTA::Get(path: "/logo.svg")]
  def logo_svg : ATH::Response
    serve_asset("logo.svg")
  end

  @[ARTA::Get(path: "/code_icon.svg")]
  def code_icon_svg : ATH::Response
    serve_asset("code_icon.svg")
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
