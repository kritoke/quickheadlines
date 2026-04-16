require "./api_base_controller"

class QuickHeadlines::Controllers::ProxyController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/proxy-image")]
  def proxy_image(request : ATH::Request) : ATH::Response
    url = request.query_params["url"]?
    raw_max = request.query_params["max"]?
    max_bytes = raw_max.try(&.to_i64?) || QuickHeadlines::Constants::PROXY_DEFAULT_MAX_BYTES.to_i64

    if url.nil? || url.strip.empty?
      return ATH::Response.new("Missing 'url' parameter", 400, HTTP::Headers{"content-type" => "text/plain"})
    end

    unless validate_proxy_url(url)
      return ATH::Response.new("Disallowed proxy domain", 403, HTTP::Headers{"content-type" => "text/plain"})
    end

    max_bytes = {max_bytes, QuickHeadlines::Constants::MAX_PROXY_IMAGE_BYTES.to_i64}.min

    if response = rate_limit_response(request, "proxy", 30, 60)
      return response
    end

    proxy_image_fetch(url, max_bytes)
  end

  private def proxy_image_fetch(url : String, max_bytes : Int64) : ATH::Response
    uri = URI.parse(url)
    client = HTTP::Client.new(uri)
    client.read_timeout = 10.seconds
    client.write_timeout = 10.seconds
    client.connect_timeout = 5.seconds

    begin
      response = client.get(uri.request_target)

      if response.status_code >= 400
        return ATH::Response.new("Bad Gateway", 502, HTTP::Headers{"content-type" => "text/plain"})
      end

      content_type = (response.headers["content-type"]? || "application/octet-stream").split(";").first

      unless content_type.starts_with?("image/")
        return ATH::Response.new("Not an image", 415, HTTP::Headers{"content-type" => "text/plain"})
      end

      content_length_header = response.headers["Content-Length"]?
      if content_length_header && (content_length = content_length_header.to_i64?) && content_length > max_bytes
        return ATH::Response.new("Image too large", 413, HTTP::Headers{"content-type" => "text/plain"})
      end

      body = response.body
      if body.bytesize > max_bytes
        return ATH::Response.new("Image too large", 413, HTTP::Headers{"content-type" => "text/plain"})
      end

      ATH::Response.new(body, 200, HTTP::Headers{"content-type" => content_type})
    rescue ex
      Log.for("quickheadlines.http").error(exception: ex) { "Proxy image fetch error for #{url}" }
      ATH::Response.new("Bad Gateway", 502, HTTP::Headers{"content-type" => "text/plain"})
    ensure
      client.close
    end
  end

  @[ARTA::Get(path: "/favicons/{hash}.{ext}")]
  def favicon_file(request : ATH::Request, hash : String, ext : String) : ATH::Response
    unless hash.matches?(/\A[a-f0-9]{16}\z/)
      return ATH::Response.new("Invalid favicon hash", 400, HTTP::Headers{"content-type" => "text/plain"})
    end

    unless ext.in?("png", "ico", "svg", "gif", "jpg", "jpeg", "webp")
      return ATH::Response.new("Invalid favicon extension", 400, HTTP::Headers{"content-type" => "text/plain"})
    end

    favicon_path = File.join(FaviconStorage.favicon_dir, "#{hash}.#{ext}")
    unless favicon_path.starts_with?(FaviconStorage.favicon_dir)
      return ATH::Response.new("Invalid favicon path", 400, HTTP::Headers{"content-type" => "text/plain"})
    end

    if File.exists?(favicon_path)
      content = File.read(favicon_path)
      ATH::Response.new(content, 200, HTTP::Headers{"content-type" => mime_type_from_ext(ext)})
    else
      ATH::Response.new("Favicon not found", 404, HTTP::Headers{"content-type" => "text/plain"})
    end
  end
end
