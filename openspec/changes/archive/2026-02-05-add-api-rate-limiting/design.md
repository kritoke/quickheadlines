# Design: API Rate Limiting

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    RateLimiter                              │
├─────────────────────────────────────────────────────────────┤
│  - @limits : Hash(String, RateLimitInfo)  # IP -> info     │
│  - @cleanup_task : Fiber                   # Cleanup fiber  │
├─────────────────────────────────────────────────────────────┤
│  + check_limit(ip : String, category : String) : Bool      │
│  + record_request(ip : String, category : String) : Int32   │
│  + get_headers(category : String) : HTTP::Headers           │
│  + should_rate_limit?(ip : String, category : String) : Bool│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  ApiController                               │
├─────────────────────────────────────────────────────────────┤
│  - rate_limiter : RateLimiter                               │
│  - CONFIG : RateLimitConfig                                 │
├─────────────────────────────────────────────────────────────┤
│  + before_each(request : ATH::Request) : Nil                │
│  + cluster() : ATH::Response                                │
│  + recluster() : ATH::Response                              │
│  + refresh() : ATH::Response                                 │
│  + clear_cache() : ATH::Response                            │
└─────────────────────────────────────────────────────────────┘
```

### RateLimitInfo Record

```crystal
struct RateLimitInfo
  property request_count : Int32
  property window_start : Time
  property category : String

  def initialize(@category : String)
    @request_count = 0
    @window_start = Time.utc
  end

  def within_window? : Bool
    (Time.utc - @window_start) < CONFIG.window_size(@category)
  end

  def expired? : Bool
    (Time.utc - @window_start) > CONFIG.window_size(@category) * 2
  end
end
```

### Configuration

```crystal
class RateLimitConfig
  # Default limits per category (requests per window)
  DEFAULT_LIMITS = {
    "expensive"      => 5,      # /api/cluster, /api/recluster
    "moderately"     => 10,     # /api/refresh, /api/clear-cache
    "read"               # /api => 60,/feeds, /api/clusters, /api/timeline
    "very_expensive"=> 3,      # /api/cleanup-orphaned
  }

  WINDOW_SIZES = {
    "expensive"      => 1.hour,
    "moderately"     => 1.hour,
    "read"           => 1.minute,
    "very_expensive" => 1.hour,
  }

  CLEANUP_INTERVAL = 5.minutes
  MAX_ENTRIES      => 10_000  # Prevent memory exhaustion
end
```

## Implementation Details

### RateLimiter Class

```crystal
class RateLimiter
  @@instance : RateLimiter?
  @@mutex = Mutex.new

  def self.instance : RateLimiter
    @@mutex.synchronize { @@instance ||= new }
  end

  def initialize
    @limits = Hash(String, RateLimitInfo).new
    @cleanup_task = spawn cleanup_loop
    STDERR.puts "[#{Time.local}] Rate limiter initialized"
  end

  def check_limit(ip : String, category : String) : {allowed: Bool, remaining: Int32, reset_at: Int64}
    now = Time.utc
    window_key = "#{ip}:#{category}"

    info = @@mutex.synchronize do
      if existing = @limits[window_key]?
        if existing.expired?
          @limits.delete(window_key)
          RateLimitInfo.new(category)
        else
          existing
        end
      else
        RateLimitInfo.new(category).tap { |i| @limits[window_key] = i }
      end
    end

    limit = RateLimitConfig::DEFAULT_LIMITS[category]
    window_size = RateLimitConfig::WINDOW_SIZES[category]

    if info.request_count >= limit
      reset_at = info.window_start.to_unix + window_size.to_i
      return {allowed: false, remaining: 0, reset_at: reset_at}
    end

    info.request_count += 1
    remaining = limit - info.request_count
    reset_at = info.window_start.to_unix + window_size.to_i

    {allowed: true, remaining: remaining, reset_at: reset_at}
  end

  def should_rate_limit?(ip : String, category : String) : Bool
    !check_limit(ip, category).first
  end

  private def cleanup_loop
    loop do
      sleep RateLimitConfig::CLEANUP_INTERVAL
      cleanup_expired_entries
    end
  end

  private def cleanup_expired_entries
    removed = 0
    @@mutex.synchronize do
      @limits.reject! { |_, info| info.expired? }
      removed = @limits.size
    end
    STDERR.puts "[#{Time.local}] Rate limit cleanup: #{removed} active entries"
  end

  def stats : {total_entries: Int32, categories: Hash(String, Int32)}
    categories = Hash(String, Int32).new(0)
    @@mutex.synchronize do
      @limits.each { |key, info| categories[info.category] += 1 }
      {total_entries: @limits.size, categories: categories}
    end
  end
end
```

### Before Hook Integration

```crystal
# In ApiController
@[ARTA::Before_action]
def rate_limit_requests(request : ATH::Request) : ATH::Response?
  ip = request.remote_address || "unknown"
  endpoint = request.path

  category = case endpoint
             when "/api/cluster", "/api/recluster"  then "expensive"
             when "/api/refresh", "/api/clear-cache" then "moderately"
             when "/api/cleanup-orphaned"           then "very_expensive"
             else                                       "read"
             end

  result = RateLimiter.instance.check_limit(ip, category)

  unless result[:allowed]
    STDERR.puts "[#{Time.local}] Rate limit exceeded for #{ip} on #{endpoint}"
    return ATH::Response.new(
      "Rate limit exceeded. Try again later.",
      429,
      HTTP::Headers{
        "Content-Type"    => "text/plain",
        "Retry-After"     => result[:reset_at].to_s,
        "X-RateLimit-Limit"  => RateLimitConfig::DEFAULT_LIMITS[category].to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset"  => result[:reset_at].to_s,
      }
    )
  end

  # Add rate limit headers to all responses
  request.response.headers["X-RateLimit-Limit"] = RateLimitConfig::DEFAULT_LIMITS[category].to_s
  request.response.headers["X-RateLimit-Remaining"] = result[:remaining].to_s
  request.response.headers["X-RateLimit-Reset"] = result[:reset_at].to_s

  nil  # Continue to handler
end
```

### Admin Status Endpoint

```crystal
@[ARTA::Get(path: "/api/admin/rate-limit-stats")]
def rate_limit_stats : Quickheadlines::DTOs::RateLimitStatsResponse
  stats = RateLimiter.instance.stats
  Quickheadlines::DTOs::RateLimitStatsResponse.new(
    total_entries: stats[:total_entries],
    by_category: stats[:categories]
  )
end
```

## Response Headers

All rate-limited responses include:

```
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 3
X-RateLimit-Reset: 1738684800
Retry-After: 3600  (only on 429 responses)
```

## File Changes

| File | Change |
|------|--------|
| `src/rate_limiter.cr` | New file - RateLimiter class |
| `src/dtos/rate_limit_stats_dto.cr` | New file - Stats DTO |
| `src/controllers/api_controller.cr` | Add before hook and stats endpoint |
| `src/config.cr` | Add rate limit config section |

## Testing

```crystal
describe RateLimiter do
  describe "check_limit" do
    it "allows requests within limit" do
      result = RateLimiter.instance.check_limit("127.0.0.1", "read")
      result[:allowed].should be_true
      result[:remaining].should eq(59)
    end

    it "blocks requests over limit" do
      60.times { RateLimiter.instance.check_limit("127.0.0.1", "read") }
      result = RateLimiter.instance.check_limit("127.0.0.1", "read")
      result[:allowed].should be_false
    end

    it "tracks different IPs separately" do
      RateLimiter.instance.check_limit("127.0.0.1", "read")
      result = RateLimiter.instance.check_limit("192.168.1.1", "read")
      result[:allowed].should be_true
    end
  end
end
```

## Performance Considerations

- O(1) lookup for rate limit checks
- Periodic cleanup prevents memory growth
- Mutex only held briefly during updates
- Configurable limits to tune for deployment
