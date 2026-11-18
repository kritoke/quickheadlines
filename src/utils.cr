require "socket"
require "http/client"
require "uri"
require "./constants"

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

  KNOWN_PRIVATE_HOSTS = {
    "localhost",
    "0.0.0.0",
    "::1",
    "[::1]",
    "::ffff:127.0.0.1",
    "[::ffff:127.0.0.1]",
    "::ffff:0.0.0.0",
    "[::ffff:0.0.0.0]",
  }

  def self.private_host?(host : String) : Bool
    return true if KNOWN_PRIVATE_HOSTS.includes?(host)
    return true if host.starts_with?("[::") || host.starts_with?("fe80::") || host.starts_with?("[fe80::")
    return true if host.downcase.starts_with?("::ffff:")
    return true if PRIVATE_PREFIXES.any? { |prefix| host.starts_with?(prefix) }
    return private_cidr_range?(host, QuickHeadlines::Constants::CGNAT_RANGE_MIN_BITS, QuickHeadlines::Constants::CGNAT_RANGE_MAX_BITS) if host.starts_with?("100.")
    return private_cidr_range?(host, QuickHeadlines::Constants::PRIVATE_172_MIN_BITS, QuickHeadlines::Constants::PRIVATE_172_MAX_BITS) if host.starts_with?("172.")
    false
  end

  # True if the address is loopback, private (RFC1918 / fc00::/7), link-local,
  # unspecified, CGNAT (100.64.0.0/10), or an IPv4-mapped form of any of those.
  def self.non_public_ip?(ip : Socket::IPAddress) : Bool
    return true if ip.loopback? || ip.private? || ip.link_local? || ip.unspecified?
    addr = ip.address
    if ip.family.inet6? && addr.downcase.starts_with?("::ffff:")
      v4 = addr[7..]
      return Socket::IPAddress.valid_v4?(v4) ? non_public_ip?(Socket::IPAddress.new(v4, 0)) : true
    end
    if ip.family.inet?
      octets = addr.split('.').map(&.to_i)
      return true if octets[0] == 0                                     # 0.0.0.0/8
      return true if octets[0] == 100 && (64..127).includes?(octets[1]) # CGNAT
    end
    false
  end

  # Resolves `host` and returns true if ANY resolved address is non-public,
  # or if resolution fails (fail closed). Use this before fetching any URL
  # whose host comes from untrusted content (feeds, HTML).
  def self.resolves_to_private?(host : String) : Bool
    h = host.lchop('[').rchop(']')
    return true if private_host?(h)
    if Socket::IPAddress.valid?(h)
      return non_public_ip?(Socket::IPAddress.new(h, 0))
    end
    addrs = Socket::Addrinfo.resolve(h, 80, type: Socket::Type::STREAM)
    return true if addrs.empty?
    addrs.any? { |a| non_public_ip?(a.ip_address) }
  rescue Socket::Error | IO::Error | ArgumentError
    true
  end

  private def self.private_cidr_range?(host : String, min : Int32, max : Int32) : Bool
    parts = host.split('.')
    return false unless parts.size >= 2
    second = parts[1].to_i?(strict: true)
    !second.nil? && second >= min && second <= max
  end

  def self.read_body_safe(io : IO, max_size : Int32 = QuickHeadlines::Constants::MAX_REQUEST_BODY_SIZE) : String
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
  def self.read_binary_file(path : String) : String
    bytes = File.open(path, "rb", &.getb_to_end)
    String.new(bytes)
  end

  def self.mime_type_from_path(path : String) : String
    ext = File.extname(path).lchop('.')
    mime_type_from_ext(ext)
  end

  def self.mime_type_from_ext(ext : String) : String
    MIME_TYPES[ext.downcase]? || "application/octet-stream"
  end

  # Returns the client IP for rate limiting / logging.
  #
  # The TCP peer address is authoritative. Client-supplied headers are only
  # honored when TRUSTED_PROXY is set AND the peer itself is a private/loopback
  # address (i.e. the request really came through a local reverse proxy). In that
  # case the right-most X-Forwarded-For entry is used, since it is the one appended
  # by the trusted proxy and cannot be forged by the client.
  def self.extract_client_ip(request : HTTP::Request) : String
    peer = peer_ip(request)

    if ENV["TRUSTED_PROXY"]? && peer && private_host?(peer)
      if xff = request.headers["X-Forwarded-For"]?
        if forwarded = xff.split(',').map(&.strip).reject(&.empty?).last?
          return forwarded
        end
      end
      if real = request.headers["X-Real-IP"]?.try(&.strip)
        return real unless real.empty?
      end
    end

    peer || "unknown"
  end

  def self.peer_ip(request : HTTP::Request) : String?
    addr = request.remote_address
    addr.is_a?(Socket::IPAddress) ? addr.address : nil
  end

  # Timing-safe string comparison to prevent timing attacks on auth tokens.
  def self.timing_safe_compare(a : String, b : String) : Bool
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
