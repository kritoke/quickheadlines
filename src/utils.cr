require "http/client"
require "uri"
require "./constants"

CONCURRENCY_SEMAPHORE = Channel(Nil).new(QuickHeadlines::Constants::CONCURRENCY).tap { |channel| QuickHeadlines::Constants::CONCURRENCY.times { channel.send(nil) } }

# Atomic counter to track available semaphore slots without draining the channel.
# Updated on every acquire/release; read by health check for zero-side-effect inspection.
CONCURRENCY_AVAILABLE = Atomic(Int32).new(QuickHeadlines::Constants::CONCURRENCY)

# Thread-safe semaphore helpers: update both channel and atomic counter together.
def acquire_semaphore : Nil
  CONCURRENCY_SEMAPHORE.receive
  CONCURRENCY_AVAILABLE.sub(1, :relaxed)
end

def release_semaphore : Nil
  CONCURRENCY_SEMAPHORE.send(nil)
  CONCURRENCY_AVAILABLE.add(1, :relaxed)
end

def semaphore_health_status : NamedTuple(available: Int32, expected: Int32)
  {available: CONCURRENCY_AVAILABLE.get(:relaxed), expected: QuickHeadlines::Constants::CONCURRENCY}
end

module Utils
  MIME_TYPES = {
    "html"  => "text/html; charset=utf-8",
    "htm"   => "text/html; charset=utf-8",
    "css"   => "text/css; charset=utf-8",
    "js"    => "application/javascript; charset=utf-8",
    "json"  => "application/json",
    "woff"  => "font/woff",
    "woff2" => "font/woff2",
    "png"   => "image/png",
    "ico"   => "image/x-icon",
    "svg"   => "image/svg+xml",
    "gif"   => "image/gif",
    "jpg"   => "image/jpeg",
    "jpeg"  => "image/jpeg",
    "webp"  => "image/webp",
  }

  PRIVATE_PREFIXES = ["127.", "192.168.", "10.", "169.254."]

  def self.parse_ip_address(address : String) : String?
    return if address.nil? || address.empty?

    addr_str = address.to_s

    if addr_str.starts_with?("[") && addr_str.includes?("]:")
      addr_str.split("]:").first.lchop("[")
    elsif addr_str.count(':') > 1
      if port_match = addr_str.match(/:(\d+)$/)
        addr_str[0...-port_match[0].size]
      else
        addr_str
      end
    else
      addr_str.split(":").first
    end
  end

  def self.private_host?(host : String) : Bool
    return true if host == "localhost"
    return true if host == "0.0.0.0"
    return true if host == "::1" || host == "[::1]"
    return true if host.starts_with?("[::")
    return true if host.starts_with?("fe80::") || host.starts_with?("[fe80::")
    return true if PRIVATE_PREFIXES.any? { |prefix| host.starts_with?(prefix) }
    return private_cidr_range?(host, QuickHeadlines::Constants::CGNAT_RANGE_MIN_BITS, QuickHeadlines::Constants::CGNAT_RANGE_MAX_BITS) if host.starts_with?("100.")
    return private_cidr_range?(host, QuickHeadlines::Constants::PRIVATE_172_MIN_BITS, QuickHeadlines::Constants::PRIVATE_172_MAX_BITS) if host.starts_with?("172.")
    false
  end

  private def self.private_cidr_range?(host : String, min : Int32, max : Int32) : Bool
    parts = host.split('.')
    return false unless parts.size >= 2
    second = parts[1].to_i?(strict: true)
    !second.nil? && second >= min && second <= max
  end
end

def read_body_safe(io : IO, max_size : Int32 = QuickHeadlines::Constants::MAX_REQUEST_BODY_SIZE) : String
  # Use growing buffer instead of fixed max-size allocation
  buffer = IO::Memory.new
  buffer_bytes = Bytes.new(QuickHeadlines::Constants::BUFFER_SIZE) # 8KB chunk
  bytes_copied = 0

  while bytes_copied < max_size
    bytes_read = io.read(buffer_bytes)
    break if bytes_read == 0
    buffer.write(buffer_bytes[0, bytes_read])
    bytes_copied += bytes_read
  end

  if bytes_copied >= max_size && io.read_byte
    raise IO::EOFError.new("Request body exceeds #{max_size} bytes")
  end

  buffer.to_s
end

# Read a file as binary data, preserving raw bytes without UTF-8 decoding.
# Use this for image files (ICO, PNG, etc.) where File.read would corrupt
# non-UTF-8 byte sequences by replacing them with U+FFFD.
def read_binary_file(path : String) : String
  bytes = File.open(path, "rb", &.getb_to_end)
  String.new(bytes)
end

module UrlNormalizer
  FEED_SUFFIXES = {"/feed.xml", "/feed", "/rss.xml", "/rss", "/atom"}

  def self.normalize(url : String) : String
    normalized = url.strip

    # Intentional: upgrade http to https — most RSS feeds support HTTPS,
    # and this prevents duplicate cache entries for the same feed over different schemes
    normalized = "https://#{normalized[7..-1]}" if normalized.starts_with?("http://")

    normalized = normalized.sub("https://www.", "https://").sub("http://www.", "http://")

    normalized = normalized.rchop('/')

    FEED_SUFFIXES.each do |suffix|
      normalized = normalized.rchop(suffix) if normalized.ends_with?(suffix)
    end

    if query_index = normalized.index('?')
      normalized = normalized[0...query_index]
    end
    if fragment_index = normalized.index('#')
      normalized = normalized[0...fragment_index]
    end

    normalized
  end
end

def mime_type_from_path(path : String) : String
  ext = File.extname(path).lchop('.')
  mime_type_from_ext(ext)
end

def mime_type_from_ext(ext : String) : String
  Utils::MIME_TYPES[ext.downcase]? || "application/octet-stream"
end

def extract_client_ip(request) : String
  if ENV["TRUSTED_PROXY"]?
    # SECURITY NOTE: This trusts X-Forwarded-For from any client.
    # Only enable if your deployment ensures only trusted proxies can reach this server
    # (e.g., firewall rules, VPN, or direct server access is blocked).
    # For safer behavior, use X-Client-IP from your reverse proxy instead.
    Log.for("quickheadlines.utils").warn { "TRUSTED_PROXY enabled - ensure only trusted proxies can reach this server" } if ENV["APP_ENV"]? && ENV["APP_ENV"] == "development"
    if xff = request.headers["X-Forwarded-For"]?
      if first_ip = xff.split(",").first?.try(&.strip)
        # Additional validation: only trust X-Forwarded-For if it appears to be from an internal/proxy source
        # (loopback, private range, or internal network). This prevents direct client IP spoofing.
        if Utils.private_host?(first_ip) || first_ip == "localhost" || first_ip.starts_with?("127.") || first_ip.starts_with?("[::1")
          return first_ip
        end
        # For non-internal IPs, log and fall through to X-Client-IP
        Log.for("quickheadlines.utils").debug { "TRUSTED_PROXY: X-Forwarded-For #{first_ip} not from internal range, using X-Client-IP" }
      end
    end
  end
  request.headers["X-Client-IP"]?.try(&.strip) || "unknown"
end

# Timing-safe string comparison to prevent timing attacks on auth tokens.
def timing_safe_compare(a : String, b : String) : Bool
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
