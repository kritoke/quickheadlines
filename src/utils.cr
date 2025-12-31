require "http/client"
require "uri"

# ----- HTTP client pooling and concurrency control -----

class ClientPool
  def for(url : String) : HTTP::Client
    uri = URI.parse(url)
    client = HTTP::Client.new(uri)
    client.compress = true
    client.read_timeout = 15.seconds
    client.connect_timeout = 10.seconds
    client
  end
end

POOL = ClientPool.new

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

def resolve_url(url : String?, base : String) : String?
  return if url.nil? || url.strip.empty?
  URI.parse(base).resolve(url.strip).to_s
rescue
  nil
end
