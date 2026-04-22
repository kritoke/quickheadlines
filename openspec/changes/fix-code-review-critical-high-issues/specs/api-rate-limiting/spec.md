## ADDED Requirements

### Requirement: Rate limiting on feed listing endpoint
`GET /api/feeds` SHALL be rate limited to prevent abuse. Each unique client IP SHALL be limited to 60 requests per 60-second sliding window.

#### Scenario: Normal usage is allowed
- **WHEN** a client makes 60 requests within 60 seconds from the same IP
- **THEN** all requests are served successfully

#### Scenario: Excessive requests are rate limited
- **WHEN** a client makes more than 60 requests within 60 seconds from the same IP
- **THEN** the 61st+ request returns HTTP 429 Too Many Requests
- **AND** the response includes a `Retry-After` header indicating when the client may retry

### Requirement: Rate limiting on timeline endpoint
`GET /api/timeline` SHALL be rate limited to prevent abuse. Each unique client IP SHALL be limited to 60 requests per 60-second sliding window.

#### Scenario: Normal usage is allowed
- **WHEN** a client makes 60 requests within 60 seconds from the same IP
- **THEN** all requests are served successfully

#### Scenario: Excessive requests are rate limited
- **WHEN** a client makes more than 60 requests within 60 seconds from the same IP
- **THEN** the 61st+ request returns HTTP 429 Too Many Requests
- **AND** the response includes a `Retry-After` header indicating when the client may retry

### Requirement: Use existing rate limiter infrastructure
The implementation SHALL use the existing `RateLimiter` class (defined in `src/rate_limiter.cr`) with the key format `"api_feeds:{ip}"` and `"api_timeline:{ip}"`. Rate limiter instances SHALL be created via `RateLimiter.get_or_create()` to benefit from automatic cleanup of stale instances.

### Requirement: Rate limiting does not affect admin endpoints
Admin endpoints (`POST /api/cluster`, `POST /api/admin`, `GET /api/status`) SHALL retain their existing stricter rate limits (1 request per minute) and SHALL NOT share rate limit state with public API endpoints.
