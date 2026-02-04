# Specification: API Rate Limiting

## Overview

This specification defines the rate limiting behavior for the QuickHeadlines API. Rate limiting protects against abuse while allowing legitimate use of the API.

## Definitions

### Terms
- **Client IP**: The remote address of the requester, used as the rate limit key
- **Rate Limit Category**: A group of endpoints with similar sensitivity
- **Window**: The time period over which requests are counted
- **Limit**: The maximum number of requests allowed per window

## Rate Limit Categories

### Category: `expensive`
**Description**: Endpoints that perform computationally expensive operations like clustering

| Property | Value |
|----------|-------|
| Limit | 5 requests |
| Window | 1 hour |
| Endpoints | `/api/cluster`, `/api/recluster` |

**Rationale**: Clustering operations involve MinHash computation and database queries. Limiting these prevents resource exhaustion.

### Category: `moderately`
**Description**: Endpoints that modify cache or trigger feed operations

| Property | Value |
|----------|-------|
| Limit | 10 requests |
| Window | 1 hour |
| Endpoints | `/api/refresh`, `/api/clear-cache` |

**Rationale**: Cache operations can be expensive and should be rate limited but with slightly higher limits than expensive operations.

### Category: `read`
**Description**: Read-only endpoints that fetch data

| Property | Value |
|----------|-------|
| Limit | 60 requests |
| Window | 1 minute |
| Endpoints | `/api/feeds`, `/api/clusters`, `/api/timeline`, `/api/timeline/*`, `/api/status`, `/api/feed/*` |

**Rationale**: These endpoints are read-only and can handle higher throughput. 60/minute allows for normal usage patterns.

### Category: `very_expensive`
**Description**: Operations that affect entire database

| Property | Value |
|----------|-------|
| Limit | 3 requests |
| Window | 1 hour |
| Endpoints | `/api/cleanup-orphaned` |

**Rationale**: Database cleanup operations should be very limited.

## Behavior

### Request Processing Flow

```
1. Extract client IP from request
2. Determine endpoint category
3. Check rate limit for (IP, category)
4. If exceeded:
   - Return HTTP 429 with Retry-After header
   - Log rate limit exceeded event
5. If allowed:
   - Increment request count
   - Add rate limit headers to response
   - Continue request processing
```

### Rate Limit Headers

All responses include these headers:

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Maximum requests allowed | `5` |
| `X-RateLimit-Remaining` | Requests remaining in window | `3` |
| `X-RateLimit-Reset` | Unix timestamp when window resets | `1738684800` |

### 429 Response

When rate limit is exceeded:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: text/plain
Retry-After: 3600
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1738684800

Rate limit exceeded. Try again later.
```

- `Retry-After`: Seconds until the client can retry
- HTTP Status: 429 (not 403 or 429 + body)

## Implementation Requirements

### Thread Safety
- All rate limit state must be protected by mutex
- Concurrent requests from same IP must be handled correctly

### Memory Management
- Periodic cleanup of expired entries
- Maximum entry limit to prevent memory exhaustion
- Sliding window for accurate limiting

### Configuration
Rate limits must be configurable via config.yaml:

```yaml
rate_limiting:
  enabled: true
  categories:
    expensive:
      limit: 5
      window_minutes: 60
    moderately:
      limit: 10
      window_minutes: 60
    read:
      limit: 60
      window_minutes: 1
    very_expensive:
      limit: 3
      window_minutes: 60
  cleanup_interval_minutes: 5
  max_entries: 10000
```

### Defaults
If configuration is missing, use these defaults:
- `expensive.limit`: 5
- `moderately.limit`: 10
- `read.limit`: 60
- `very_expensive.limit`: 3
- `window_minutes`: 60 for all except read (1)
- `cleanup_interval_minutes`: 5
- `max_entries`: 10000

## Edge Cases

### Missing IP Address
If request has no remote address:
- Use a default key like `"unknown"`
- Allow requests (don't block entirely)
- Log warning

### Bursts at Window Boundary
When a client's window resets:
- New requests should be allowed immediately
- Count resets to 0 for new window

### Multiple Categories
If client hits multiple category limits:
- Each category tracked independently
- Hitting one limit doesn't affect others

### Admin Endpoints
- `/api/admin/rate-limit-stats` should not be rate limited
- Available for monitoring rate limiter status

## Monitoring

### Statistics Endpoint
`GET /api/admin/rate-limit-stats`

Response:
```json
{
  "total_entries": 1250,
  "by_category": {
    "expensive": 50,
    "moderately": 75,
    "read": 1000,
    "very_expensive": 25
  }
}
```

### Logging
Log rate limit events:
- `INFO`: Rate limit check performed
- `WARN`: Rate limit exceeded for IP/endpoint
- `ERROR`: Rate limiter errors (if any)

### Metrics (Future)
Consider adding metrics for:
- Requests allowed vs blocked per category
- Average remaining requests
- Unique IPs tracked

## Security Considerations

### IP Spoofing
- Rate limiting is based on `remote_address`
- For reverse proxy setups, use `X-Forwarded-For` header
- Validate and sanitize header values

### Circumvention
- Rate limiting by IP is best-effort
- Sophisticated attackers can use different IPs
- Consider additional measures for high-value endpoints

## Test Cases

### Category: Read
```gherkin
Scenario: Normal read usage
  Given a client makes 60 requests to /api/feeds
  When the 61st request is made
  Then the response is HTTP 429
  And the Retry-After header is present
```

### Category: Expensive
```gherkin
Scenario: Clustering operation limit
  Given a client makes 5 requests to /api/recluster
  When the 6th request is made
  Then the response is HTTP 429
  And the X-RateLimit-Remaining header is "0"
```

### Category Reset
```gherkin
Scenario: Window reset allows new requests
  Given a client has exhausted their limit
  When 1 hour passes
  And the client makes a new request
  Then the response is HTTP 200
  And X-RateLimit-Remaining is 4
```

### Different IPs
```gherkin
Scenario: Different IPs tracked separately
  Given client A has 4 requests remaining
  When client B makes a request to the same endpoint
  Then client B should have 59 requests remaining
```

## Compliance Checklist

- [ ] RateLimiter class implemented with thread safety
- [ ] All sensitive endpoints protected
- [ ] Rate limit headers included in responses
- [ ] HTTP 429 returned when limit exceeded
- [ ] Configuration via config.yaml
- [ ] Periodic cleanup of expired entries
- [ ] Admin stats endpoint implemented
- [ ] Unit tests cover all categories
- [ ] Integration tests verify end-to-end behavior
- [ ] Documentation updated
