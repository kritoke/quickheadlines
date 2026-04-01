require "./api_base_controller"

class QuickHeadlines::Controllers::ProxyController < QuickHeadlines::Controllers::ApiBaseController
  @[ARTA::Get(path: "/api/proxy-image")]
  def proxy_image(request : ATH::Request) : ATH::Response
    url = request.query_params["url"]?
    max_bytes = (request.query_params["max"]? || "2097152").to_i64

    if url.nil? || url.strip.empty?
      return ATH::Response.new("Missing 'url' parameter", 400, HTTP::Headers{"content-type" => "text/plain"})
    end

    unless validate_proxy_url(url)
      return ATH::Response.new("Invalid or disallowed proxy URL", 403, HTTP::Headers{"content-type" => "text/plain"})
    end

    if max_bytes > Constants::MAX_PROXY_IMAGE_BYTES
      max_bytes = Constants::MAX_PROXY_IMAGE_BYTES
    end

    ip = client_ip(request)
    limiter = RateLimiter.get_or_create("proxy:#{ip}", 30, 60)

    unless limiter.allowed?(ip)
      retry_after = limiter.retry_after(ip)
      return ATH::Response.new(
        "Rate limit exceeded",
        429,
        HTTP::Headers{
          "content-type" => "text/plain",
          "Retry-After"  => retry_after.to_s,
        }
      )
    end

    begin
      uri = URI.parse(url)
      client = HTTP::Client.new(uri)
      client.read_timeout = 10.seconds
      client.connect_timeout = 5.seconds

      response = client.get(uri.request_target)

      if response.status_code >= 400
        return ATH::Response.new("Upstream error: #{response.status_code}", 502, HTTP::Headers{"content-type" => "text/plain"})
      end

      content_type = response.headers["content-type"]? || "application/octet-stream"
      content_type = content_type.split(";").first

      unless content_type.starts_with?("image/")
        return ATH::Response.new("Not an image", 415, HTTP::Headers{"content-type" => "text/plain"})
      end

      body = response.body
      if body.bytesize > max_bytes
        return ATH::Response.new("Image too large (#{body.bytesize} > #{max_bytes})", 413, HTTP::Headers{"content-type" => "text/plain"})
      end

      ATH::Response.new(body, 200, HTTP::Headers{"content-type" => content_type})
    rescue ex
      ATH::Response.new("Proxy error: #{ex.message}", 502, HTTP::Headers{"content-type" => "text/plain"})
    end
  end

  @[ARTA::Get(path: "/_app/favicon/{hash}.{ext}")]
  def favicon_file(request : ATH::Request, hash : String, ext : String) : ATH::Response
    favicon_path = FaviconStorage.favicon_dir + "/#{hash}.#{ext}"

    if File.exists?(favicon_path)
      content = File.read(favicon_path)
      mime_type = case ext
                  when "png" then "image/png"
                  when "ico" then "image/x-icon"
                  when "svg" then "image/svg+xml"
                  when "gif" then "image/gif"
                  when "jpg" then "image/jpeg"
                  when "jpeg" then "image/jpeg"
                  else "application/octet-stream"
                  end
      return ATH::Response.new(content, 200, HTTP::Headers{"content-type" => mime_type})
    else
      ATH::Response.new("Favicon not found", 404, HTTP::Headers{"content-type" => "text/plain"})
    end
  end
end