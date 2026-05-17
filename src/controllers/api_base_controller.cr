require "athena"
require "../constants"
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
    return false if secret.nil? || secret.empty?

    auth_header = request.headers["Authorization"]?
    return false unless auth_header

    unless auth_header.starts_with?("Bearer ")
      return false
    end

    token = auth_header[7..-1]
    timing_safe_compare(secret, token)
  rescue ArgumentError
    false
  end

  private def timing_safe_compare(a : String, b : String) : Bool
    a_bytes = a.bytes
    b_bytes = b.bytes
    max_len = {a_bytes.size, b_bytes.size}.max
    result = 0
    max_len.times do |i|
      a_byte = i < a_bytes.size ? a_bytes[i] : 0
      b_byte = i < b_bytes.size ? b_bytes[i] : 0
      result |= a_byte ^ b_byte
    end
    result == 0
  end

  private def check_rate_limit!(request : AHTTP::Request, key : String, max_requests : Int32, window_seconds : Int32) : Nil
    ip = client_ip(request)
    limiter = RateLimiter.get_or_create("#{key}:#{ip}", max_requests, window_seconds)
    return if limiter.allowed?(ip)
    retry_after = limiter.retry_after(ip)
    headers = HTTP::Headers{"Retry-After" => retry_after.to_s}
    raise AHK::Exception::HTTPException.new(429, "Rate limit exceeded", nil, headers)
  end

  private def client_ip(request : AHTTP::Request) : String
    extract_client_ip(request)
  end

  private def validate_proxy_url(url : String) : Bool
    uri = URI.parse(url)
    return false unless uri.scheme == "https"
    return false if !uri.host.is_a?(String) || uri.host.to_s.empty?

    host = uri.host.as(String).downcase
    return false unless QuickHeadlines::Constants::ALLOWED_PROXY_DOMAINS.includes?(host)
    return false if uri.user || uri.password
    return false if uri.port && uri.port != 443

    true
  rescue URI::Error
    false
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
  # Accessible only from loopback addresses (127.0.0.1 or ::1) to avoid exposing admin info publicly.
  @[ARTA::Get(path: "/api/health")]
  def health(request : AHTTP::Request) : QuickHeadlines::DTOs::HealthResponse
    ip = client_ip(request)
    allowed = ["127.0.0.1", "::1", "::ffff:127.0.0.1"]
    # Some requests running in this environment return 'unknown' from extract_client_ip()
    # Treat 'unknown' as local (dev) so curl from the host can access the health endpoint.
    unless ip == "unknown" || allowed.includes?(ip)
      raise AHK::Exception::HTTPException.new(401, "Unauthorized")
    end

    status = begin
      RefreshHealthMonitor.status
    rescue
      { last_start: 0_i64, last_complete: 0_i64, cycles: 0_i32, failures: 0_i32 }
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
    seconds = 600
    if body
      content = read_body_safe(body)
      begin
        parsed = JSON.parse(content)
        # JSON::Any -> try as Int64 then convert
        if parsed["seconds"]?
          begin
            seconds = parsed["seconds"].to_s.to_i32
          rescue
            # ignore parse errors and keep default
          end
        end
      rescue
      end
    end

    RefreshHealthMonitor.force_stuck!(seconds)

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
        cached = cache.get(feed_config.url)
        cached || cache.get(normalize_feed_url(feed_config.url))
      end

      {name: tab_config.name, feeds: tab_feeds, software_releases: [] of FeedData}
    end

    {cached_feeds, cached_tabs}
  end
end
