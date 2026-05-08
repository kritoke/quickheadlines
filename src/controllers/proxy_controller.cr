require "./api_base_controller"
require "../favicon_cache"

class QuickHeadlines::Controllers::ProxyController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/proxy-image")]
  def proxy_image(request : AHTTP::Request) : AHTTP::Response
    url = request.query_params["url"]?
    raw_max = request.query_params["max"]?
    # Parse max parameter and clamp to hard ceiling to prevent abuse
    max_bytes : Int64 = QuickHeadlines::Constants::PROXY_DEFAULT_MAX_BYTES.to_i64
    if (parsed = raw_max.try(&.to_i64?))
      max_bytes = {parsed, QuickHeadlines::Constants::PROXY_MAX_ALLOWED_BYTES}.min
      max_bytes = {max_bytes, 1_i64}.max
    end

    raise AHK::Exception::BadRequest.new("Missing 'url' parameter") if url.nil? || url.strip.empty?
    raise AHK::Exception::HTTPException.new(403, "Disallowed proxy domain") unless validate_proxy_url(url)

    check_rate_limit!(request, "proxy", 30, 60)

    proxy_image_fetch(url, max_bytes)
  end

  private def proxy_image_fetch(url : String, max_bytes : Int64) : AHTTP::Response
    uri = URI.parse(url)
    client = HTTP::Client.new(uri)
    client.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
    client.write_timeout = QuickHeadlines::Constants::HTTP_WRITE_TIMEOUT.seconds
    client.connect_timeout = QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds

    begin
      response = client.get(uri.request_target)

      if response.status_code >= 400
        raise AHK::Exception::HTTPException.new(502, "Bad Gateway")
      end

      content_type = (response.headers["content-type"]? || "application/octet-stream").split(";").first

      unless content_type.starts_with?("image/")
        raise AHK::Exception::HTTPException.new(415, "Not an image")
      end

      content_length_header = response.headers["Content-Length"]?
      if content_length_header && (content_length = content_length_header.to_i64?) && content_length > max_bytes
        raise AHK::Exception::HTTPException.new(413, "Image too large")
      end

      body = response.body
      if body.bytesize > max_bytes
        raise AHK::Exception::HTTPException.new(413, "Image too large")
      end

      AHTTP::Response.new(body, 200, HTTP::Headers{
        "content-type"           => content_type,
        "cache-control"          => "public, max-age=86400",
        "x-content-type-options" => "nosniff",
      })
    rescue ex : AHK::Exception::HTTPException
      raise ex
    rescue ex
      Log.for("quickheadlines.http").error(exception: ex) { "Proxy image fetch error for #{url}" }
      raise AHK::Exception::HTTPException.new(502, "Bad Gateway")
    ensure
      client.close
    end
  end

  @[ARTA::Get(path: "/favicons/{hash}.{ext}")]
  def favicon_file(request : AHTTP::Request, hash : String, ext : String) : AHTTP::Response
    raise AHK::Exception::BadRequest.new("Invalid favicon hash") unless hash.matches?(/\A[a-f0-9]{16}\z/)
    raise AHK::Exception::BadRequest.new("Invalid favicon extension") unless ext.in?("png", "ico", "svg", "gif", "jpg", "jpeg", "webp")

    favicon_path = File.join(FaviconStorage.favicon_dir, "#{hash}.#{ext}")
    raise AHK::Exception::BadRequest.new("Invalid favicon path") unless favicon_path.starts_with?(FaviconStorage.favicon_dir)

    cache_key = "#{hash}.#{ext}"

    cached = FaviconCache.get(cache_key)
    if cached
      AHTTP::Response.new(cached, 200, HTTP::Headers{
        "content-type"           => mime_type_from_ext(ext),
        "cache-control"          => "public, max-age=604800, immutable",
        "x-content-type-options" => "nosniff",
      })
    else
      raise AHK::Exception::NotFound.new("Favicon not found") unless File.exists?(favicon_path)

      content = File.read(favicon_path)
      FaviconCache.put(cache_key, content)
      AHTTP::Response.new(content, 200, HTTP::Headers{
        "content-type"           => mime_type_from_ext(ext),
        "cache-control"          => "public, max-age=604800, immutable",
        "x-content-type-options" => "nosniff",
      })
    end
  end
end
