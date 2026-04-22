## ADDED Requirements

### Requirement: Admin endpoints require authentication
All admin endpoints (`/api/cluster`, `/api/admin`) SHALL require valid API key authentication.

#### Scenario: Valid admin key provided
- **WHEN** client makes request to `/api/cluster` with header `X-Admin-Key: <valid_key>`
- **THEN** request is processed normally

#### Scenario: No admin key provided
- **WHEN** client makes request to `/api/cluster` without `X-Admin-Key` header
- **THEN** response status code is 401
- **THEN** response body contains "Admin authentication required"

#### Scenario: Invalid admin key provided
- **WHEN** client makes request to `/api/cluster` with header `X-Admin-Key: invalid`
- **THEN** response status code is 403
- **THEN** response body contains "Invalid admin key"

#### Scenario: Admin key not configured
- **WHEN** admin key is not set in configuration
- **THEN** admin endpoints return 503 with "Admin access not configured"

### Requirement: Admin key is configurable
The admin API key SHALL be configurable via config file.

#### Scenario: Admin key in config
- **WHEN** `security.admin_key` is set in feeds.yml
- **THEN** that value is used for authentication
- **WHEN** `security.admin_key` is not set
- **THEN** admin endpoints return 503 (access not configured)

### Requirement: Admin access attempts are logged
All admin endpoint access attempts SHALL be logged with result.

#### Scenario: Failed admin access logged
- **WHEN** client provides invalid admin key
- **THEN** access attempt is logged with IP address and timestamp
