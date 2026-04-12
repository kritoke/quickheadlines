require "http/client"
require "uri"
require "./constants"

# ----- HTTP client pooling and concurrency control -----

# Debug mode helper - only logs if debug is enabled
def debug_log(message : String) : Nil
  if config = StateStore.config
    if config.debug?
      STDOUT.puts "[DEBUG] #{message}"
    end
  end
end

# Try HTTPS first for HTTP URLs (upgrades URLs for security)
def try_https_first(url : String) : String
  if url.starts_with?("http://")
    https_url = "https://" + url[7..-1]
    debug_log("Trying HTTPS first for: #{https_url}")
    https_url
  else
    url
  end
end

# Create HTTP client with optional configuration from STATE.config
def create_client(url : String) : HTTP::Client
  # Try HTTPS first for HTTP URLs
  uri_url = try_https_first(url)
  uri = URI.parse(uri_url)
  client = HTTP::Client.new(uri)
  client.compress = true

  # Apply default timeouts
  client.read_timeout = QuickHeadlines::Constants::HTTP_READ_TIMEOUT.seconds
  client.connect_timeout = QuickHeadlines::Constants::HTTP_CONNECT_TIMEOUT.seconds

  client
end

# Limit concurrent fetches (helps smooth peak allocations)
# Adjust capacity to your environment (5–10 is a good start).
CONCURRENCY_SEMAPHORE = Channel(Nil).new(QuickHeadlines::Constants::CONCURRENCY).tap { |channel| QuickHeadlines::Constants::CONCURRENCY.times { channel.send(nil) } }

def parse_time(str : String?) : Time?
  return unless str

  [
    Time::Format::RFC_2822,
    Time::Format::RFC_3339,
    Time::Format::ISO_8601_DATE_TIME,
    Time::Format::ISO_8601_DATE,
  ].each do |format|
    begin
      return format.parse(str)
    rescue Time::Format::Error
    end
  end
  nil
end

def relative_time(t : Time?) : String
  return "" unless t
  minutes = [(Time.utc - t.to_utc).total_minutes, 0.0].max

  if minutes < 60
    "#{minutes.to_i}m"
  elsif minutes < 1440
    "#{(minutes / 60).to_i}h"
  else
    "#{(minutes / 1440).to_i}d"
  end
end

# Format current date in DD/MM/YY format for fallback
def current_date_fallback : String
  Time.local.to_s("%d/%m/%y")
end

# Format time for last update header: "7:25 PM CT, January 1, 2025"
def last_updated_format(t : Time) : String
  local_time = t.to_local
  # Get timezone name from location (e.g., "America/Chicago" -> extract or use zone offset)
  timezone_abbr = local_time.location.to_s.split("/").last? || "Local"
  "#{local_time.to_s("%I:%M %p")} #{timezone_abbr}, #{local_time.to_s("%B %d, %Y")}"
end

def resolve_url(url : String?, base : String) : String?
  return if url.nil? || url.strip.empty?
  URI.parse(base).resolve(url.strip).to_s
rescue
  nil
end

module Utils
  def self.validate_feed_url(url : String) : Bool
    return false if url.nil? || url.strip.empty?

    begin
      uri = URI.parse(url.strip)
      return false unless uri.scheme
      return false unless uri.scheme.in?("http", "https")
      return false if !uri.host.is_a?(String) || uri.host.to_s.empty?
      true
    rescue URI::Error
      false
    end
  end

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
