# websocket-connection Specification

## Purpose
Maintains a single shared WebSocket connection for real-time communication with improved reconnection logic and offline message buffering.

## MODIFIED Requirements

### Requirement: WebSocket-only communication
**CHANGED:** The system SHALL use WebSocket exclusively for real-time updates. There SHALL be no periodic polling timers that independently refresh feed or timeline data. The `onReconnect` callback SHALL be the sole mechanism for catching missed updates after disconnection.

#### Scenario: Real-time updates received
- **WHEN** new feed items are available on the server
- **THEN** updates are delivered exclusively through WebSocket messages

#### Scenario: No polling endpoints used
- **WHEN** the application is running
- **THEN** no requests are made to long-polling endpoints like `/api/events`

#### Scenario: No periodic refresh timers
- **WHEN** the application is running
- **THEN** no `setInterval` or `setTimeout` loops independently trigger `/api/feeds` or `/api/timeline` refreshes on a fixed schedule

#### Scenario: Reconnection triggers data refresh
- **WHEN** the WebSocket connection is restored after a disconnection
- **THEN** the `onReconnect` callback fetches fresh data from `/api/feeds` and `/api/timeline`

### Requirement: Exponential backoff reconnection
The system SHALL implement exponential backoff with jitter for WebSocket connection reconnection attempts.

#### Scenario: First reconnection attempt
- **WHEN** the WebSocket connection is first disconnected
- **THEN** the system attempts to reconnect after approximately 1 second (1s base + random jitter)

#### Scenario: Second reconnection attempt
- **WHEN** the second reconnection attempt fails
- **THEN** the system attempts to reconnect after approximately 2 seconds (2s base + random jitter)

#### Scenario: Third+ reconnection attempts
- **WHEN** subsequent reconnection attempts fail
- **THEN** the delay doubles each attempt (4s, 8s, 16s...) up to a maximum of 30 seconds

#### Scenario: Maximum delay reached
- **WHEN** the delay reaches 30 seconds
- **THEN** subsequent attempts continue at 30 seconds with jitter

#### Scenario: Successful connection resets delay
- **WHEN** a reconnection attempt succeeds
- **THEN** the delay resets to 1 second for the next disconnection

### Requirement: Message queue during disconnect
The system SHALL queue messages during network disconnection and deliver them on reconnection.

#### Scenario: Message received during disconnect
- **WHEN** a message arrives while the WebSocket is disconnected
- **THEN** the message is queued locally (up to 100 messages)

#### Scenario: Connection restored
- **WHEN** the WebSocket reconnects after having queued messages
- **THEN** queued messages are delivered to listeners in order

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
