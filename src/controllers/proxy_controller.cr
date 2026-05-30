require "./api_base_controller"
require "../favicon_cache"

class QuickHeadlines::Controllers::ProxyController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/proxy-image")]
  def proxy_image(request : AHTTP::Request) : AHTTP::Response
    url = request.query_params["url"]?
    raw_max = request.query_params["max"]?
    # Parse max parameter and clamp to hard ceiling to prevent abuse
    max_bytes : Int64 = QuickHeadlines::Constants::PROXY_DEFAULT_MAX_BYTES.to_i64
    if parsed = raw_max.try(&.to_i64?)
      max_bytes = {parsed, QuickHeadlines::Constants::PROXY_MAX_ALLOWED_BYTES}.min
      max_bytes = {max_bytes, 1_i64}.max
    end

    raise AHK::Exception::BadRequest.new("Missing 'url' parameter") if url.nil? || url.strip.empty?

    check_rate_limit!(request, "proxy", 30, 60)

    # proxy_image_fetch validates URL + resolves DNS with pinning
    proxy_image_fetch(url, max_bytes)
  end

  private def proxy_image_fetch(url : String, max_bytes : Int64) : AHTTP::Response
    uri = URI.parse(url)

    # Validate and resolve DNS once — pin to prevent rebinding
    valid, resolved_ip = validate_proxy_url_with_ip(url)
    raise AHK::Exception::HTTPException.new(403, "Disallowed proxy domain") unless valid

    client = create_pinned_client(uri, resolved_ip)

    begin
      # Follow redirects manually with validation + DNS pinning
      target_uri = uri
      response_headers = follow_redirects(client, target_uri, resolved_ip)

      # Validate content type before streaming body
      content_type = (response_headers["content-type"]? || "application/octet-stream").split(";").first
      unless content_type.starts_with?("image/")
        raise AHK::Exception::HTTPException.new(415, "Not an image")
      end

      content_length_header = response_headers["Content-Length"]?
      if content_length_header && (content_length = content_length_header.to_i64?) && content_length > max_bytes
        raise AHK::Exception::HTTPException.new(413, "Image too large")
      end

      # Final GET with streaming body read to enforce size limit
      body_bytes = Bytes.empty
      client.get(target_uri.request_target) do |response|
        if response.status_code >= 400
          raise AHK::Exception::HTTPException.new(502, "Bad Gateway")
        end

        body = IO::Memory.new
        buf = Bytes.new(8192)
        loop do
          bytes_read = response.body_io.read(buf)
          break if bytes_read == 0
          body.write(buf[0, bytes_read])
          if body.bytesize > max_bytes
            raise AHK::Exception::HTTPException.new(413, "Image too large")
          end
        end
        body_bytes = body.to_slice
      end

      AHTTP::Response.new(String.new(body_bytes), 200, HTTP::Headers{
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

  # Follow redirects with validation + DNS pinning. Mutates client and returns final response headers.
  private def follow_redirects(client : HTTP::Client, target_uri : URI, resolved_ip : String?) : HTTP::Headers
    response = client.get(target_uri.request_target)

    while response.status_code >= 300 && response.status_code < 400
      redirect_location = response.headers["Location"]?
      unless redirect_location
        raise AHK::Exception::HTTPException.new(502, "Bad Gateway")
      end

      redirect_valid, redirect_ip = validate_proxy_url_with_ip(redirect_location)
      unless redirect_valid
        Log.for("quickheadlines.proxy").warn { "Redirect to unvalidated URL blocked: #{redirect_location}" }
        raise AHK::Exception::HTTPException.new(403, "Disallowed redirect domain")
      end

      redirect_uri = URI.parse(redirect_location)
      client.close
      client = create_pinned_client(redirect_uri, redirect_ip)
      target_uri = redirect_uri
      response = client.get(redirect_uri.request_target)
    end

    if response.status_code >= 400
      raise AHK::Exception::HTTPException.new(502, "Bad Gateway")
    end

    response.headers
  end

  @[ARTA::Get(path: "/favicons/{hash}.{ext}")]
  def favicon_file(request : AHTTP::Request, hash : String, ext : String) : AHTTP::Response
    raise AHK::Exception::BadRequest.new("Invalid favicon hash") unless hash.matches?(/\A[a-f0-9]{16}\z/)
    raise AHK::Exception::BadRequest.new("Invalid favicon extension") unless ext.in?("png", "ico", "svg", "gif", "jpg", "jpeg", "webp")

    favicon_path = File.expand_path(File.join(FaviconStorage.favicon_dir, "#{hash}.#{ext}"))
    favicon_base = File.expand_path(FaviconStorage.favicon_dir) + "/"
    raise AHK::Exception::BadRequest.new("Invalid favicon path") unless favicon_path.starts_with?(favicon_base)

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

      # Read favicon as binary to avoid UTF-8 corruption of ICO files.
      # File.read decodes as UTF-8, replacing invalid byte sequences with U+FFFD.
      content = read_binary_file(favicon_path)
      FaviconCache.put(cache_key, content)
      AHTTP::Response.new(content, 200, HTTP::Headers{
        "content-type"           => mime_type_from_ext(ext),
        "cache-control"          => "public, max-age=604800, immutable",
        "x-content-type-options" => "nosniff",
      })
    end
  end
end
