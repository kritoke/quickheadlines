require "./api_base_controller"

class QuickHeadlines::Controllers::ProxyController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/proxy-image")]
  def proxy_image(request : ATH::Request) : ATH::Response
    url = request.query_params["url"]?
    raw_max = request.query_params["max"]?
    max_bytes = raw_max.try(&.to_i64?) || QuickHeadlines::Constants::PROXY_DEFAULT_MAX_BYTES.to_i64

    raise ATH::Exception::BadRequest.new("Missing 'url' parameter") if url.nil? || url.strip.empty?
    raise ATH::Exception::HTTPException.new(403, "Disallowed proxy domain") unless validate_proxy_url(url)

    max_bytes = {max_bytes, QuickHeadlines::Constants::MAX_PROXY_IMAGE_BYTES.to_i64}.min

    check_rate_limit!(request, "proxy", 30, 60)

    proxy_image_fetch(url, max_bytes)
  end

  private def proxy_image_fetch(url : String, max_bytes : Int64) : ATH::Response
    uri = URI.parse(url)
    client = HTTP::Client.new(uri)
    client.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
    client.write_timeout = QuickHeadlines::Constants::HTTP_WRITE_TIMEOUT.seconds
    client.connect_timeout = QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds

    begin
      response = client.get(uri.request_target)

      if response.status_code >= 400
        raise ATH::Exception::HTTPException.new(502, "Bad Gateway")
      end

      content_type = (response.headers["content-type"]? || "application/octet-stream").split(";").first

      unless content_type.starts_with?("image/")
        raise ATH::Exception::HTTPException.new(415, "Not an image")
      end

      content_length_header = response.headers["Content-Length"]?
      if content_length_header && (content_length = content_length_header.to_i64?) && content_length > max_bytes
        raise ATH::Exception::HTTPException.new(413, "Image too large")
      end

      body = response.body
      if body.bytesize > max_bytes
        raise ATH::Exception::HTTPException.new(413, "Image too large")
      end

      ATH::Response.new(body, 200, HTTP::Headers{"content-type" => content_type})
    rescue ex : ATH::Exception::HTTPException
      raise ex
    rescue ex
      Log.for("quickheadlines.http").error(exception: ex) { "Proxy image fetch error for #{url}" }
      raise ATH::Exception::HTTPException.new(502, "Bad Gateway")
    ensure
      client.close
    end
  end

  @[ARTA::Get(path: "/favicons/{hash}.{ext}")]
  def favicon_file(request : ATH::Request, hash : String, ext : String) : ATH::Response
    raise ATH::Exception::BadRequest.new("Invalid favicon hash") unless hash.matches?(/\A[a-f0-9]{16}\z/)
    raise ATH::Exception::BadRequest.new("Invalid favicon extension") unless ext.in?("png", "ico", "svg", "gif", "jpg", "jpeg", "webp")

    favicon_path = File.join(FaviconStorage.favicon_dir, "#{hash}.#{ext}")
    raise ATH::Exception::BadRequest.new("Invalid favicon path") unless favicon_path.starts_with?(FaviconStorage.favicon_dir)

    if File.exists?(favicon_path)
      content = File.read(favicon_path)
      ATH::Response.new(content, 200, HTTP::Headers{"content-type" => mime_type_from_ext(ext)})
    else
      raise ATH::Exception::NotFound.new("Favicon not found")
    end
  end
end
