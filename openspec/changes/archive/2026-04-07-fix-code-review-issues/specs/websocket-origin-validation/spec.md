## ADDED Requirements

### Requirement: WebSocket Origin validation
The system SHALL validate the Origin header on incoming WebSocket connections to prevent cross-site WebSocket hijacking.

#### Scenario: Valid origin accepted
- **WHEN** a WebSocket connection request has an Origin header matching the server's Host header
- **THEN** the connection is accepted

#### Scenario: Missing origin accepted
- **WHEN** a WebSocket connection request has no Origin header (direct connection)
- **THEN** the connection is accepted

#### Scenario: Invalid origin rejected
- **WHEN** a WebSocket connection request has an Origin header that does not match the server's Host
- **THEN** the connection is closed immediately

#### Scenario: Cross-site WebSocket blocked
- **WHEN** a malicious website attempts to open a WebSocket connection from a victim's browser
- **THEN** the connection is rejected because the Origin does not match the server host
