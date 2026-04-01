require "athena"
require "../constants"
require "../dtos/config_dto"
require "../web/assets"
require "../services/feed_service"
require "../services/story_service"
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
  @feed_service : QuickHeadlines::Services::FeedService?
  @clustering_service : QuickHeadlines::Services::ClusteringService?

  ALLOWED_DOMAINS = {
    "i.imgur.com",
    "pbs.twimg.com",
    "avatars.githubusercontent.com",
    "lh3.googleusercontent.com",
    "i.pravatar.cc",
    "images.unsplash.com",
    "fastly.picsum.photos",
  }

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
    return true if secret.nil? || secret.empty?

    auth_header = request.headers["Authorization"]?
    return false unless auth_header

    unless auth_header.starts_with?("Bearer ")
      return false
    end

    token = auth_header[7..-1]
    timing_safe_compare(secret, token)
  rescue
    false
  end

  private def timing_safe_compare(a : String, b : String) : Bool
    return false unless a.bytesize == b.bytesize

    result = 0
    a_bytes = a.bytes
    b_bytes = b.bytes
    a_bytes.each_with_index do |byte, i|
      result |= byte ^ b_bytes[i]
    end
    result == 0
  end

  private def unauthorized_response : ATH::Response
    ATH::Response.new("Unauthorized", 401, HTTP::Headers{"content-type" => "text/plain"})
  end

  private def client_ip(request : ATH::Request) : String
    if ENV["TRUSTED_PROXY"]?
      if xff = request.headers["X-Forwarded-For"]?
        if last_ip = xff.split(",").last?.try(&.strip)
          return last_ip
        end
      end
    end
    request.headers["X-Client-IP"]?.try(&.strip) || request.headers["Host"]? || "unknown"
  end

  private def validate_proxy_url(url : String) : Bool
    uri = URI.parse(url)
    return false unless uri.scheme.in?("http", "https")
    return false unless uri.host.is_a?(String) && !uri.host.to_s.empty?

    host = uri.host.as(String)
    !Utils.private_host?(host)
  rescue
    false
  end

  private def validate_int(value : String?, default : Int32, min : Int32? = nil, max : Int32? = nil) : Int32
    return default unless value

    parsed = value.to_i32?
    return default unless parsed

    parsed = min.not_nil! if min && parsed < min
    parsed = max.not_nil! if max && parsed > max
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

  private def feed_service : QuickHeadlines::Services::FeedService
    @feed_service ||= QuickHeadlines::Services::FeedService.new(@db_service)
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
        cached || cache.get(normalize_url(feed_config.url))
      end
      {name: tab_config.name, feeds: tab_feeds, software_releases: [] of FeedData}
    end

    {cached_feeds, cached_tabs}
  end

  protected def normalize_url(url : String) : String
    UrlNormalizer.normalize(url)
  end
end