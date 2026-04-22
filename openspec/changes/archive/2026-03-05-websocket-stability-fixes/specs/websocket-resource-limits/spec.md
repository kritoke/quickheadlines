## ADDED Requirements

### Requirement: Global Connection Limit
The WebSocket server SHALL enforce a maximum number of concurrent connections.

#### Scenario: Maximum connections reached
- **WHEN** A new client attempts to connect
- **AND** The current connection count equals max_connections (default: 1000)
- **THEN** The connection upgrade SHALL be rejected
- **AND** An appropriate HTTP status (503) SHALL be returned

#### Scenario: Connection count below maximum
- **WHEN** A new client attempts to connect
- **AND** The current connection count is below max_connections
- **THEN** The connection SHALL be accepted

### Requirement: Per-IP Connection Limit
The WebSocket server SHALL enforce a maximum number of connections per source IP address.

#### Scenario: Same IP exceeds limit
- **WHEN** A client from IP X attempts to connect
- **AND** IP X already has max_connections_per_ip (default: 10) connections
- **THEN** The connection upgrade SHALL be rejected
- **AND** An appropriate HTTP status (503) SHALL be returned

#### Scenario: Different IPs within limits
- **WHEN** Multiple clients from different IPs connect
- **AND** Each IP is within its per-IP limit
- **AND** Total connections are within global limit
- **THEN** All connections SHALL be accepted

### Requirement: Janitor Cleanup
A background fiber SHALL periodically check for and remove dead connections.

#### Scenario: Dead connection detected
- **WHEN** Janitor fiber runs its check
- **AND** A connection has no outgoing activity for 5 minutes
- **AND** The WebSocket is not actively open
- **THEN** The connection SHALL be removed from SocketManager
- **AND** The writer fiber for that connection SHALL be terminated

#### Scenario: Janitor runs on schedule
- **WHEN** 60 seconds have passed since last Janitor run
- **THEN** Janitor SHALL check all registered connections
- **AND** Dead connections SHALL be cleaned up
