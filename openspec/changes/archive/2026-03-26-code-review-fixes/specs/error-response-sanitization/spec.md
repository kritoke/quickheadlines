## ADDED Requirements

### Requirement: Generic Error Messages to Clients

The HTTP controllers SHALL return generic error messages to clients, preventing information disclosure about internal implementation details.

#### Scenario: Static file error returns generic message
- **WHEN** a request for a static asset fails with an exception
- **THEN** the response body SHALL be "Internal server error"
- **AND** the response status SHALL be 500
- **AND** the actual exception message SHALL NOT be sent to the client

#### Scenario: Error details logged to stderr
- **WHEN** a request for a static asset fails with an exception
- **THEN** the actual exception message and backtrace SHALL be written to STDERR

#### Scenario: NoSuchFileError returns generic 404
- **WHEN** a request matches no static asset route
- **THEN** the response body SHALL be "Not Found" with status 404
- **AND** the specific missing path SHALL NOT be disclosed to the client

### Requirement: Security Headers on All Responses

Static file responses SHALL include appropriate security headers.

#### Scenario: X-Content-Type-Options header set
- **WHEN** a static file is served
- **THEN** the `X-Content-Type-Options` header SHALL be set to "nosniff"

#### Scenario: X-Frame-Options header set
- **WHEN** a static file is served
- **THEN** the `X-Frame-Options` header SHALL be set to "DENY"

#### Scenario: Content-Security-Policy on HTML
- **WHEN** an HTML file is served
- **THEN** a CSP header SHALL be included with appropriate self-referencing policies
