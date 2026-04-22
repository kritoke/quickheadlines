## ADDED Requirements

### Requirement: IP-aware rate limiting for sensitive endpoints
The system SHALL derive per-client rate limit keys from the client's IP address for `/api/admin` and `/api/cluster` endpoints, providing per-client isolation.

#### Scenario: Different IPs have independent rate limits
- **WHEN** client A (IP 1.2.3.4) makes 1 request to `/api/cluster`
- **AND** client B (IP 5.6.7.8) makes 1 request to `/api/cluster`
- **AND** client A makes a second request within 60 seconds
- **THEN** client A's second request is rate-limited (429)
- **AND** client B's requests are not affected

#### Scenario: X-Forwarded-For respected behind trusted proxy
- **WHEN** `TRUSTED_PROXY` env var is set
- **AND** a request arrives with header `X-Forwarded-For: 203.0.113.50, 198.51.100.178`
- **THEN** the rate limit key is derived from `203.0.113.50` (first IP in chain)

#### Scenario: Falls back to remote_address when X-Forwarded-For is missing
- **WHEN** `TRUSTED_PROXY` env var is set
- **AND** a request arrives without `X-Forwarded-For` header
- **THEN** the rate limit key is derived from `request.remote_address`

#### Scenario: X-Forwarded-For ignored when TRUSTED_PROXY is not set
- **WHEN** `TRUSTED_PROXY` env var is not set
- **AND** a request arrives with header `X-Forwarded-For: 203.0.113.50`
- **THEN** the rate limit key is derived from `request.remote_address` (XFF is ignored)

## MODIFIED Requirements

### Requirement: Rate limiter memory cleanup
**Original text**: The system SHALL periodically clean up stale entries from the rate limiter to prevent unbounded memory growth.

**Updated text**: The system SHALL periodically clean up stale entries from the rate limiter to prevent unbounded memory growth. Rate limit keys MAY be derived from client identifiers (e.g., IP address) rather than fixed endpoint strings.

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

#### Scenario: Per-IP keys cleaned up independently
- **WHEN** client A (IP 1.2.3.4) made requests but client B (IP 5.6.7.8) has not
- **AND** cleanup runs
- **THEN** only client A's stale entries are removed if old enough
- **AND** client B's entries (if any) are preserved
