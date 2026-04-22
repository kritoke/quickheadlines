## ADDED Requirements

### Requirement: Bearer token authentication for sensitive endpoints
When the `ADMIN_SECRET` environment variable is set, the system SHALL require a valid Bearer token for `/api/admin` and `/api/cluster` endpoints.

#### Scenario: Auth enabled — valid token accepted
- **WHEN** `ADMIN_SECRET` env var is set to `"mysecret"`
- **AND** a request to `/api/admin` or `/api/cluster` includes header `Authorization: Bearer mysecret`
- **THEN** the request is processed normally

#### Scenario: Auth enabled — invalid token rejected
- **WHEN** `ADMIN_SECRET` env var is set to `"mysecret"`
- **AND** a request to `/api/admin` or `/api/cluster` includes header `Authorization: Bearer wrongtoken` or no header
- **THEN** the server returns `401 Unauthorized` with body `"Unauthorized"`

#### Scenario: Auth disabled — no token required
- **WHEN** `ADMIN_SECRET` env var is not set or is empty
- **AND** a request to `/api/admin` or `/api/cluster` is made without an Authorization header
- **THEN** the request is processed normally (backward-compatible)

#### Scenario: Auth enabled — empty secret treated as disabled
- **WHEN** `ADMIN_SECRET` env var is set to an empty string `""`
- **THEN** the system behaves as if auth is disabled (no token required)

### Requirement: Unauthorized requests return JSON error
The system SHALL return a JSON error response body for 401 responses from protected endpoints.

#### Scenario: 401 response includes error body
- **WHEN** a request to a protected endpoint is rejected due to invalid or missing token
- **THEN** the response status is `401`
- **AND** the response body is `{"error": "Unauthorized"}`
- **AND** the `content-type` header is `application/json`
