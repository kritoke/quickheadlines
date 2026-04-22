## ADDED Requirements

### Requirement: HTTP Rate Limiting
The system SHALL enforce rate limiting on all HTTP endpoints including admin.

#### Scenario: Rate limit exceeded
- **WHEN** client exceeds rate limit
- **THEN** HTTP 429 is returned with Retry-After header

#### Scenario: Rate limit applied to admin endpoints
- **WHEN** admin endpoint is called rapidly
- **THEN** rate limiting is enforced

### Requirement: WebSocket Rate Limiting
The system SHALL enforce rate limiting on WebSocket connections.

#### Scenario: WebSocket rate limit exceeded
- **WHEN** WebSocket client sends too many messages
- **THEN** connection is throttled or closed
