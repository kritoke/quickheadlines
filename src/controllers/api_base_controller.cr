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

  private def check_admin_auth(request : ATH::Request) : Bool
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

  private def check_rate_limit!(request : ATH::Request, key : String, max_requests : Int32, window_seconds : Int32) : Nil
    ip = client_ip(request)
    limiter = RateLimiter.get_or_create("#{key}:#{ip}", max_requests, window_seconds)
    return if limiter.allowed?(ip)
    retry_after = limiter.retry_after(ip)
    headers = HTTP::Headers{"Retry-After" => retry_after.to_s}
    raise ATH::Exception::HTTPException.new(429, "Rate limit exceeded", nil, headers)
  end

  private def client_ip(request : ATH::Request) : String
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
