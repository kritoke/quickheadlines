## MODIFIED Requirements

### Requirement: Rate limit configuration
The system SHALL allow configuring rate limit parameters.

#### Scenario: Custom rate limit settings
- **WHEN** RateLimiter.configure is called with max_requests and window_seconds
- **THEN** subsequent requests use the new limits

#### Scenario: Default rate limit
- **WHEN** RateLimiter is instantiated without configuration
- **THEN** default values are 60 requests per 60 seconds

#### Scenario: Thread-safe instance retrieval
- **WHEN** multiple concurrent requests arrive for the same rate limiter key
- **THEN** only one instance is created and shared among all requestors
- **AND** no race condition occurs during instance lookup or creation

#### Scenario: Stale instances cleaned up after TTL
- **WHEN** a rate limiter instance has not been accessed for longer than the TTL (3600 seconds)
- **THEN** it is removed during the next cleanup cycle
- **AND** new requests create fresh instances

## ADDED Requirements

### Requirement: Rate limiter instance thread safety
The system SHALL ensure thread-safe access to the rate limiter instance cache to prevent duplicate instances or data races.

#### Scenario: Concurrent get_or_create calls
- **WHEN** two or more requests call get_or_create with the same key simultaneously
- **THEN** only one RateLimiter instance is created
- **AND** all requests receive the same instance

#### Scenario: Cleanup during concurrent access
- **WHEN** the cleanup fiber removes stale instances while another request calls get_or_create
- **THEN** no race condition causes crashes or corrupted state
- **AND** a stale instance may be cleaned up or retained depending on access timing
