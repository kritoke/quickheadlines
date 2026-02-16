require "http/client"
require "uri"

# ----- HTTP client pooling and concurrency control -----

# Debug mode helper - only logs if debug is enabled
def debug_log(message : String) : Nil
  if config = STATE.config
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

  # Apply configuration from STATE.config if available
  if config = STATE.config
    if http_config = config.http_client
      client.read_timeout = http_config.timeout.seconds
      client.connect_timeout = http_config.connect_timeout.seconds

      # Note: Proxy support would require creating client with proxy URI directly
      # For now, proxy configuration is logged but not applied
      if http_config.proxy
        STDERR.puts "[INFO] Proxy configured but not yet supported: #{http_config.proxy}"
      end
    else
      # Default timeouts if no config
      client.read_timeout = 30.seconds
      client.connect_timeout = 10.seconds
    end
  else
    client.read_timeout = 30.seconds
    client.connect_timeout = 10.seconds
  end

  client
end

# Limit concurrent fetches (helps smooth peak allocations)
# Adjust capacity to your environment (5–10 is a good start).
CONCURRENCY = 8
SEM         = Channel(Nil).new(CONCURRENCY).tap { |channel| CONCURRENCY.times { channel.send(nil) } }

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
    rescue
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
