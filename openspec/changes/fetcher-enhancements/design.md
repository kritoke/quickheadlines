# Design: fetcher-enhancements

## 1. Retry Logic

Add a configurable retry mechanism to all drivers:

```crystal
class RetryConfig
  property max_retries : Int32 = 3
  property base_delay : Time::Span = 1.second
  property max_delay : Time::Span = 30.seconds
  property exponential_base : Float64 = 2.0
end
```

- Default: 3 retries with exponential backoff (1s, 2s, 4s)
- Only retry on transient errors (timeouts, 5xx, 429)
- Do NOT retry on 4xx errors (except 429)

## 2. Item Limits

Pass limit parameter through to RSS parsing:

```crystal
def pull(url : String, headers : HTTP::Headers, etag : String?, last_modified : String?, limit : Int32 = 100) : Result
```

- Default limit: 100 items
- Apply limit during parsing, not after
- Return early when limit reached

## 3. Rate Limiting

Add GitHub API rate limit handling:

```crystal
# Check for rate limit headers in response
def handle_rate_limit(response : HTTP::Client::Response) : Bool
  if response.status_code == 429
    reset_time = response.headers["X-RateLimit-Reset"]?
    return true if reset_time
  end
  false
end
```

- Parse `X-RateLimit-*` headers
- Wait until reset time if rate limited
- Implement smarter retry with proper delays

## 4. Connection Pooling

Reuse HTTP clients instead of creating per-request:

```crystal
class HTTPClientPool
  @@clients = Hash(String, HTTP::Client).new
  
  def self.get(uri : URI) : HTTP::Client
    key = "#{uri.scheme}://#{uri.host}"
    @@clients[key] ||= HTTP::Client.new(uri)
  end
end
```

## 5. Logging

Add optional logging support:

```crystal
module Fetcher
  class_property logger : (String -> Void)? = nil
  
  def self.log(msg : String)
    logger.try(&.call(msg))
  end
end
```

- Default: nil (no logging)
- Caller can set logger for observability
- Log: fetch attempts, retries, errors, rate limits
