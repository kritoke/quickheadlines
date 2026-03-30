## ADDED Requirements

### Requirement: Rate limiter memory cleanup
The system SHALL periodically clean up stale entries from the rate limiter to prevent unbounded memory growth.

#### Scenario: Stale entries cleaned up periodically
- **WHEN** more than 60 seconds have passed since last cleanup
- **AND** a new request comes in
- **THEN** entries with no recent requests are removed from the hash

#### Scenario: Active entries preserved
- **WHEN** an identifier has made requests within the window
- **THEN** that identifier's entry is preserved during cleanup

#### Scenario: Memory doesn't grow unbounded
- **WHEN** rate limiter runs for extended period with many unique IPs
- **THEN** memory usage remains stable due to cleanup

### Requirement: Rate limit configuration
The system SHALL allow configuring rate limit parameters.

#### Scenario: Custom rate limit settings
- **WHEN** RateLimiter.configure is called with max_requests and window_seconds
- **THEN** subsequent requests use the new limits

#### Scenario: Default rate limit
- **WHEN** RateLimiter is instantiated without configuration
- **THEN** default values are 60 requests per 60 seconds
