## ADDED Requirements

### Requirement: API endpoints respond to versioned paths
All API endpoints SHALL be accessible under `/api/v1/` prefix in addition to unversioned `/api/` paths.

#### Scenario: Unversioned request receives deprecation header
- **WHEN** client makes request to `/api/timeline` without version in path
- **THEN** response includes header `Deprecation: true`
- **THEN** response includes header `Sunset: <date>` with deprecation date
- **THEN** response includes header `Link: </api/v1/timeline>; rel="alternate"`

#### Scenario: Versioned request works normally
- **WHEN** client makes request to `/api/v1/timeline`
- **THEN** response is identical to current unversioned response
- **THEN** no deprecation headers are included

### Requirement: Versioned endpoints are documented
The API documentation SHALL indicate the version of each endpoint.

#### Scenario: API returns version in response
- **WHEN** client requests any `/api/v1/` endpoint
- **THEN** response includes `X-API-Version: v1` header

### Requirement: Invalid version returns error
Requests to unsupported API versions SHALL return appropriate error.

#### Scenario: Request to unsupported version
- **WHEN** client makes request to `/api/v2/timeline`
- **THEN** response status code is 400
- **THEN** response body contains error message about unsupported version

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
