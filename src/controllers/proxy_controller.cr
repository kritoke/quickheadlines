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

  MAX_PROXY_REDIRECTS = 5

  private def proxy_image_fetch(url : String, max_bytes : Int64) : AHTTP::Response
    current_uri = URI.parse(url)

    # Validate and resolve DNS once per hop — pin to prevent rebinding
    valid, resolved_ip = validate_proxy_url_with_ip(url)
    raise AHK::Exception::HTTPException.new(403, "Disallowed proxy domain") unless valid

    redirects = 0
    loop do
      client = create_pinned_client(current_uri, resolved_ip)
      next_location : String? = nil
      result : AHTTP::Response? = nil

      begin
        # One request per hop: the body is streamed from the same response
        # whose status/headers were validated.
        client.get(current_uri.request_target) do |response|
          if response.status_code >= 300 && response.status_code < 400
            next_location = response.headers["Location"]?
            raise AHK::Exception::HTTPException.new(502, "Bad Gateway") unless next_location
          else
            result = read_image_response(response, max_bytes)
          end
        end
      rescue ex : AHK::Exception::HTTPException
        raise ex
      rescue ex
        Log.for("quickheadlines.http").error(exception: ex) { "Proxy image fetch error for #{url}" }
        raise AHK::Exception::HTTPException.new(502, "Bad Gateway")
      ensure
        client.close
      end

      if r = result
        return r
      end

      redirects += 1
      raise AHK::Exception::HTTPException.new(502, "Too many redirects") if redirects > MAX_PROXY_REDIRECTS

      # Resolve relative Location headers against the current URL
      redirect_uri = current_uri.resolve(next_location.not_nil!)
      redirect_valid, redirect_ip = validate_proxy_url_with_ip(redirect_uri.to_s)
      unless redirect_valid
        Log.for("quickheadlines.proxy").warn { "Redirect to unvalidated URL blocked: #{redirect_uri}" }
        raise AHK::Exception::HTTPException.new(403, "Disallowed redirect domain")
      end
      current_uri = redirect_uri
      resolved_ip = redirect_ip
    end
  end

  private def read_image_response(response : HTTP::Client::Response, max_bytes : Int64) : AHTTP::Response
    raise AHK::Exception::HTTPException.new(502, "Bad Gateway") if response.status_code >= 400

    content_type = (response.headers["content-type"]? || "application/octet-stream").split(";").first.strip
    unless content_type.starts_with?("image/")
      raise AHK::Exception::HTTPException.new(415, "Not an image")
    end

    if (cl = response.headers["Content-Length"]?) && (content_length = cl.to_i64?) && content_length > max_bytes
      raise AHK::Exception::HTTPException.new(413, "Image too large")
    end

    body = IO::Memory.new
    buf = Bytes.new(8192)
    loop do
      bytes_read = response.body_io.read(buf)
      break if bytes_read == 0
      body.write(buf[0, bytes_read])
      raise AHK::Exception::HTTPException.new(413, "Image too large") if body.bytesize > max_bytes
    end

    AHTTP::Response.new(String.new(body.to_slice), 200, HTTP::Headers{
      "content-type"           => content_type,
      "cache-control"          => "public, max-age=86400",
      "x-content-type-options" => "nosniff",
    })
  end

  @[ARTA::Get(path: "/favicons/{hash}.{ext}")]
  def favicon_file(request : AHTTP::Request, hash : String, ext : String) : AHTTP::Response
    raise AHK::Exception::BadRequest.new("Invalid favicon hash") unless hash.matches?(/\A[a-f0-9]{16}\z/)
    raise AHK::Exception::BadRequest.new("Invalid favicon extension") unless ext.in?("png", "ico", "svg", "gif", "jpg", "jpeg", "webp")

    favicon_path = File.expand_path(File.join(FaviconActor.favicon_dir, "#{hash}.#{ext}"))
    favicon_base = File.expand_path(FaviconActor.favicon_dir) + "/"
    raise AHK::Exception::BadRequest.new("Invalid favicon path") unless favicon_path.starts_with?(favicon_base)

    cache_key = "#{hash}.#{ext}"

    cached = FaviconCache.get(cache_key)
    if cached
      AHTTP::Response.new(cached, 200, HTTP::Headers{
        "content-type"           => ::Utils.mime_type_from_ext(ext),
        "cache-control"          => "public, max-age=604800, immutable",
        "x-content-type-options" => "nosniff",
      })
    else
      raise AHK::Exception::NotFound.new("Favicon not found") unless File.exists?(favicon_path)

      # Read favicon as binary to avoid UTF-8 corruption of ICO files.
      # File.read decodes as UTF-8, replacing invalid byte sequences with U+FFFD.
      content = ::Utils.read_binary_file(favicon_path)
      FaviconCache.put(cache_key, content)
      AHTTP::Response.new(content, 200, HTTP::Headers{
        "content-type"           => ::Utils.mime_type_from_ext(ext),
        "cache-control"          => "public, max-age=604800, immutable",
        "x-content-type-options" => "nosniff",
      })
    end
  end
end
