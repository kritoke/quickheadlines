## ADDED Requirements

### Requirement: Reconnection Jitter
The frontend WebSocket client SHALL add random jitter to reconnection delays to prevent thundering herd.

#### Scenario: Server restart causes mass disconnect
- **WHEN** Server restarts and 100+ clients disconnect
- **AND** All clients attempt to reconnect
- **THEN** Each client SHALL wait a random delay between 0.5x and 1.5x the calculated backoff
- **AND** Reconnections SHALL be spread over several seconds rather than simultaneous

#### Scenario: First reconnection attempt
- **WHEN** Client disconnects for the first time
- **AND** reconnect_attempts equals 0
- **THEN** The delay SHALL be 1000ms multiplied by 2^0 (1000ms) and jitter applied
- **AND** Actual delay SHALL be between 500ms and 1500ms

### Requirement: Graceful Fallback to Polling
The frontend SHALL fall back to polling if WebSocket fails repeatedly.

#### Scenario: WebSocket fails 5 times in a row
- **WHEN** WebSocket connection fails 5 consecutive times
- **THEN** Client SHALL stop attempting WebSocket connections
- **AND** Client SHALL fall back to polling /api/events
- **AND** A warning SHALL be logged to console

#### Scenario: WebSocket recovers after fallback
- **WHEN** Client is using polling fallback
- **AND** A WebSocket connection attempt succeeds
- **THEN** Client SHALL switch back to WebSocket
- **AND** Polling SHALL be stopped

### Requirement: Maximum Reconnect Delay
The frontend SHALL cap the reconnection delay to prevent unlimited waiting.

#### Scenario: Many failed reconnection attempts
- **WHEN** Client has attempted to reconnect 10+ times
- **THEN** The delay SHALL NOT exceed maxReconnectDelay (default: 30000ms)
- **AND** Jitter SHALL still be applied to the capped delay
