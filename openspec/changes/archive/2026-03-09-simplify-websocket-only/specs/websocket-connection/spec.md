## ADDED Requirements

### Requirement: Single shared WebSocket connection
The system SHALL maintain a single shared WebSocket connection instance for real-time communication across the entire application.

#### Scenario: Connection established
- **WHEN** the application initializes
- **THEN** a single WebSocket connection is created and maintained

#### Scenario: Multiple pages access connection
- **WHEN** both feed and timeline pages are active
- **THEN** both pages use the same WebSocket connection instance

### Requirement: WebSocket-only communication
The system SHALL use WebSocket exclusively for real-time updates and SHALL NOT implement any long-polling fallback mechanisms.

#### Scenario: Real-time updates received
- **WHEN** new feed items are available on the server
- **THEN** updates are delivered exclusively through WebSocket messages

#### Scenario: No polling endpoints used
- **WHEN** the application is running
- **THEN** no requests are made to long-polling endpoints like `/api/events`

### Requirement: Simplified reconnection logic
The system SHALL implement fixed 3-second reconnection delay for WebSocket connections without exponential backoff or jitter.

#### Scenario: Connection lost
- **WHEN** the WebSocket connection is disconnected
- **THEN** the system attempts to reconnect after exactly 3 seconds

#### Scenario: Multiple reconnection attempts
- **WHEN** reconnection attempts fail repeatedly
- **THEN** each subsequent attempt still uses the same 3-second delay

### Requirement: Minimal connection states
The system SHALL maintain only three connection states: `connecting`, `connected`, and `disconnected`.

#### Scenario: Connection in progress
- **WHEN** attempting to establish a WebSocket connection
- **THEN** the connection state is `connecting`

#### Scenario: Connection established
- **WHEN** the WebSocket connection is successfully opened
- **THEN** the connection state is `connected`

#### Scenario: Connection closed
- **WHEN** the WebSocket connection is closed (intentionally or due to error)
- **THEN** the connection state is `disconnected`

### Requirement: Proper cleanup and memory management
The system SHALL properly clean up WebSocket connections and associated resources to prevent memory leaks.

#### Scenario: Application page unmounted
- **WHEN** a page component is destroyed
- **THEN** WebSocket event listeners are properly removed

#### Scenario: Connection intentionally closed
- **WHEN** the user navigates away from the application
- **THEN** the WebSocket connection is properly closed and cleaned up