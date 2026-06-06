require "athena"
require "../constants"
require "../utils"
require "../dtos/config_dto"
require "../dtos/api_responses"
require "../web/assets"
require "../services/story_service"
require "../services/feed_service"
require "../services/clustering_service"
require "../repositories/feed_repository"
require "../repositories/story_repository"
require "../repositories/cluster_repository"
require "../websocket"
require "../rate_limiter"

class QuickHeadlines::Controllers::ApiBaseController < Athena::Framework::Controller
  @db_service : DatabaseService
  @feed_cache : FeedCache
  @socket_manager : SocketManager
  @clustering_service : QuickHeadlines::Services::ClusteringService?

  def self.new : self
    db = DatabaseService.instance
    cache = FeedCache.instance
    sm = SocketManager.instance
    new(db, cache, sm)
  end

  def initialize(@db_service : DatabaseService, @feed_cache : FeedCache, @socket_manager : SocketManager)
  end

  private def check_admin_auth(request : AHTTP::Request) : Bool
    secret = ENV["ADMIN_SECRET"]?

    # Fail loudly in development if ADMIN_SECRET is not configured
    # This helps catch misconfigurations early instead of silently denying access
    if secret.nil? || secret.empty?
      if ENV["APP_ENV"] == "development"
        Log.for("quickheadlines.auth").error { "ADMIN_SECRET not configured! Set ADMIN_SECRET environment variable for admin endpoints to work." }
      else
        Log.for("quickheadlines.auth").warn { "Admin auth attempt without ADMIN_SECRET configured from #{client_ip(request)}" } if has_auth_header?(request)
      end
      return false
    end

    auth_header = request.headers["Authorization"]?
    return false unless auth_header

    unless auth_header.starts_with?("Bearer ")
      return false
    end

    token = auth_header[7..-1]
    if timing_safe_compare(secret, token)
      true
    else
      Log.for("quickheadlines.auth").warn { "Failed admin auth attempt from #{client_ip(request)}" }
      false
    end
  rescue ArgumentError
    false
  end

  private def has_auth_header?(request : AHTTP::Request) : Bool
    request.headers["Authorization"]?.try(&.starts_with?("Bearer ")) || false
  end

  private def check_rate_limit!(request : AHTTP::Request, key : String, max_requests : Int32, window_seconds : Int32) : Nil
    ip = client_ip(request)
    limiter_key = "#{key}:#{ip}"
    return if RateLimiter.allowed?(limiter_key, max_requests, window_seconds)
    retry_after = RateLimiter.retry_after(limiter_key, window_seconds)
    headers = HTTP::Headers{"Retry-After" => retry_after.to_s}
    raise AHK::Exception::HTTPException.new(429, "Rate limit exceeded", nil, headers)
  end

  private def client_ip(request : AHTTP::Request) : String
    extract_client_ip(request)
  end

  # Validate proxy URL and return resolved IP to prevent DNS rebinding.
  # Returns {valid, ip_address} where ip_address is the resolved IP for pinning.
  private def validate_proxy_url_with_ip(url : String) : {Bool, String?}
    uri = URI.parse(url)
    return {false, nil} unless uri.scheme == "https"

    host = uri.host
    return {false, nil} if host.nil? || host.empty?

    host = host.downcase
    return {false, nil} unless QuickHeadlines::Constants::ALLOWED_PROXY_DOMAINS.includes?(host)
    return {false, nil} if uri.user || uri.password
    return {false, nil} if uri.port && uri.port != QuickHeadlines::Constants::HTTPS_PORT

    # Resolve hostname once and verify IP is not private/internal.
    # Returns the IP for use in proxy_image_fetch to prevent DNS rebinding.
    begin
      addr_info = Socket::Addrinfo.resolve(host, 443, type: Socket::Type::STREAM)
      if addr = addr_info.first?
        ip_address = addr.ip_address.address
        if ::Utils.private_host?(ip_address)
          Log.for("quickheadlines.proxy").warn { "SSRF protection: #{host} resolved to private IP #{ip_address}" }
          return {false, nil}
        end
        return {true, ip_address}
      end
    rescue ex : Socket::Error | IO::Error
      Log.for("quickheadlines.proxy").warn { "DNS resolution failed for allowed domain #{host}: #{ex.message} — refusing request to prevent DNS rebinding" }
    end

    {false, nil}
  rescue URI::Error
    {false, nil}
  end

  # Backward-compatible wrapper for callers that only need bool
  private def validate_proxy_url(url : String) : Bool
    valid, _ = validate_proxy_url_with_ip(url)
    valid
  end

  # Create HTTP::Client with DNS pinned to resolved_ip to prevent rebinding.
  # If resolved_ip is nil, falls back to normal DNS resolution.
  private def create_pinned_client(uri : URI, resolved_ip : String?) : HTTP::Client
    if ip = resolved_ip
      # Pin to resolved IP, use hostname for TLS SNI and Host header
      host = uri.host || ""
      port = uri.port || 443
      tcp = TCPSocket.new(ip, port, connect_timeout: QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds)
      tcp.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
      tcp.write_timeout = QuickHeadlines::Constants::HTTP_WRITE_TIMEOUT.seconds
      tls_ctx = OpenSSL::SSL::Context::Client.new
      tls_ctx.verify_mode = OpenSSL::SSL::VerifyMode::PEER
      ssl = OpenSSL::SSL::Socket::Client.new(tcp, tls_ctx, hostname: host, sync_close: true)
      HTTP::Client.new(ssl, host: host, port: port)
    else
      client = HTTP::Client.new(uri)
      client.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
      client.write_timeout = QuickHeadlines::Constants::HTTP_WRITE_TIMEOUT.seconds
      client.connect_timeout = QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds
      client
    end
  end

  private def validate_int(value : String?, default : Int32, min : Int32? = nil, max : Int32? = nil) : Int32
    return default unless value

    parsed = value.to_i32?
    return default unless parsed

    if min && parsed < min
      parsed = min
    end
    if max && parsed > max
      parsed = max
    end
    parsed
  end

  private def validate_limit(value : String?, default : Int32, min : Int32 = 1, max : Int32 = 1000) : Int32
    validate_int(value, default, min, max)
  end

  private def validate_offset(value : String?, default : Int32 = 0) : Int32
    validate_int(value, default, 0)
  end

  private def validate_days(value : String?, default : Int32, min : Int32 = 1, max : Int32 = 365) : Int32
    validate_int(value, default, min, max)
  end

  # Local-only health endpoint: returns refresh health and StateStore counts.
  # Uses connection-level peer IP (not headers) to prevent bypass via X-Client-IP spoofing.
  @[ARTA::Get(path: "/api/health")]
  def health(request : AHTTP::Request) : QuickHeadlines::DTOs::HealthResponse
    # Read peer address directly from TCP connection — not from injectable headers
    peer = request.request.remote_address
    ip = peer.is_a?(Socket::IPAddress) ? peer.address : "unknown"
    allowed = ["127.0.0.1", "::1", "::ffff:127.0.0.1"]
    unless ip == "unknown" || allowed.includes?(ip)
      raise AHK::Exception::HTTPException.new(401, "Unauthorized")
    end

    status = begin
      RefreshHealthMonitor.status
    rescue ex : NilAssertionError | TypeCastError
      Log.for("quickheadlines.health").warn { "Health status error: #{ex.class} #{ex.message}" }
      {last_start: 0_i64, last_complete: 0_i64, cycles: 0_i32, failures: 0_i32}
    end

    QuickHeadlines::DTOs::HealthResponse.new(
      status[:last_start],
      status[:last_complete],
      status[:cycles],
      status[:failures],
      StateStore.refreshing?,
      StateStore.feeds.size,
      StateStore.tabs.size
    )
  end

  # DEV ONLY: force stuck state for testing watchdog. Local-only access.
  @[ARTA::Post(path: "/api/_dev/force_stuck")]
  def force_stuck(request : AHTTP::Request) : QuickHeadlines::DTOs::HealthResponse
    # Opt-in guard: only allow when QUICKHEADLINES_ENABLE_DEV_ENDPOINT is explicitly set to "true"
    unless ENV["QUICKHEADLINES_ENABLE_DEV_ENDPOINT"]? && ENV["QUICKHEADLINES_ENABLE_DEV_ENDPOINT"] == "true"
      # Hide the endpoint when not enabled
      raise AHK::Exception::HTTPException.new(404, "Not Found")
    end

    ip = client_ip(request)
    allowed = ["127.0.0.1", "::1", "::ffff:127.0.0.1"]
    unless ip == "unknown" || allowed.includes?(ip)
      raise AHK::Exception::HTTPException.new(401, "Unauthorized")
    end

    body = request.body
    seconds = QuickHeadlines::Constants::API_CACHE_TTL_SECONDS
    if body
      content = read_body_safe(body)
      begin
        parsed = JSON.parse(content)
        if val = parsed["seconds"]?
          seconds = val.to_s.to_i32
        end
      rescue JSON::ParseException
        # Invalid JSON — use default seconds
      rescue ArgumentError
        # Invalid number format — use default seconds
      end
    end

    QuickHeadlines::DevRefreshSimulator.force_stuck!(seconds)

    status = RefreshHealthMonitor.status
    QuickHeadlines::DTOs::HealthResponse.new(
      status[:last_start],
      status[:last_complete],
      status[:cycles],
      status[:failures],
      StateStore.refreshing?,
      StateStore.feeds.size,
      StateStore.tabs.size
    )
  end

  private def clustering_service : QuickHeadlines::Services::ClusteringService
    @clustering_service ||= QuickHeadlines::Services::ClusteringService.new(
      @db_service,
      QuickHeadlines::Repositories::ClusterRepository.new(@db_service)
    )
  end

  protected def load_feeds_from_cache_fallback(cache : FeedCache)
    config = StateStore.config
    return {[] of FeedData, [] of NamedTuple(name: String, feeds: Array(FeedData), software_releases: Array(FeedData))} unless config

    cached_feeds = [] of FeedData
    config.feeds.each do |feed_config|
      if cached = cache.get(feed_config.url)
        cached_feeds << cached
      end
    end

    cached_tabs = config.tabs.map do |tab_config|
      tab_feeds = tab_config.feeds.compact_map do |feed_config|
        cached = cache.get(feed_config.url) || cache.get(normalize_feed_url(feed_config.url))
        unless cached
          Log.for("quickheadlines.cache").debug { "Fallback: feed not in cache, dropping: #{feed_config.url}" }
        end
        cached
      end

      {name: tab_config.name, feeds: tab_feeds, software_releases: [] of FeedData}
    end

    {cached_feeds, cached_tabs}
  end
end
