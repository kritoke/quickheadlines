## ADDED Requirements

### Requirement: Parameter Validation Middleware
The system SHALL validate request parameters for all endpoints.

#### Scenario: Invalid parameter rejected
- **WHEN** request contains invalid parameters
- **THEN** HTTP 400 is returned with validation error details

#### Scenario: Valid parameter accepted
- **WHEN** request contains valid parameters
- **THEN** request proceeds to handler

### Requirement: URL Sanitization
The system SHALL sanitize and validate URLs before fetching.

#### Scenario: Invalid URL rejected
- **WHEN** a malformed URL is provided
- **THEN** the request is rejected with error

#### Scenario: URL scheme validation
- **WHEN** a URL with disallowed scheme is provided
- **THEN** only http and https are allowed
