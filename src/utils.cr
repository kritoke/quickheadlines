require "http/client"
require "uri"
require "./constants"

def debug_log(message : String) : Nil
  if config = StateStore.config
    if config.debug?
      STDOUT.puts "[DEBUG] #{message}"
    end
  end
end

CONCURRENCY_SEMAPHORE = Channel(Nil).new(QuickHeadlines::Constants::CONCURRENCY).tap { |channel| QuickHeadlines::Constants::CONCURRENCY.times { channel.send(nil) } }

module Utils
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

    private_prefixes = ["127.", "192.168.", "10.", "169.254."]
    return true if private_prefixes.any? { |prefix| host.starts_with?(prefix) }

    if host.starts_with?("100.")
      return private_cidr_range?(host, 64, 127)
    end

    if host.starts_with?("172.")
      return private_cidr_range?(host, 16, 31)
    end

    false
  end

  private def self.private_cidr_range?(host : String, min : Int32, max : Int32) : Bool
    parts = host.split('.')
    return false unless parts.size >= 2
    second = parts[1].to_i?(strict: true)
    !second.nil? && second >= min && second <= max
  end

  def self.validate_proxy_host(url : String) : Bool
    uri = URI.parse(url)
    return false unless uri.scheme.in?("http", "https")
    return false if !uri.host.is_a?(String) || uri.host.to_s.empty?

    host = uri.host.as(String).downcase
    !private_host?(host)
  rescue URI::Error
    false
  end
end

def read_body_safe(io : IO, max_size : Int32 = QuickHeadlines::Constants::MAX_REQUEST_BODY_SIZE) : String
  buffer = Bytes.new(max_size)
  index = 0
  while index < max_size
    bytes_read = io.read(buffer[index..])
    break if bytes_read == 0
    index += bytes_read
  end
  if index >= max_size && io.read_byte
    raise IO::EOFError.new("Request body exceeds #{max_size} bytes")
  end
  String.new(buffer[0, index])
end

module UrlNormalizer
  def self.normalize(url : String) : String
    normalized = url.strip

    normalized = "https://#{normalized[7..-1]}" if normalized.starts_with?("http://")

    normalized = normalized.sub("https://www.", "https://").sub("http://www.", "http://")

    normalized = normalized.rchop('/')
    normalized = normalized.rchop("/feed")
    normalized = normalized.rchop("/feed.xml")
    normalized = normalized.rchop("/rss")
    normalized = normalized.rchop("/rss.xml")
    normalized = normalized.rchop("/atom")

    if q_idx = normalized.index('?')
      normalized = normalized[0...q_idx]
    end
    if f_idx = normalized.index('#')
      normalized = normalized[0...f_idx]
    end

    normalized
  end
end
