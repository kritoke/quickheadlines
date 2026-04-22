# websocket-connection Specification

## MODIFIED Requirements

### Requirement: Connection count enforcement per IP address
The system SHALL track WebSocket connections per IP address and enforce `MAX_CONNECTIONS_PER_IP` (10) limit per IP across all connection lifecycle operations including the janitor cleanup path.

#### Scenario: IP exceeds connection limit
- **WHEN** an IP attempts to open more than 10 concurrent WebSocket connections
- **THEN** the 11th connection is rejected with a log message and the existing connections are not affected

#### Scenario: IP count is decremented exactly once per disconnect
- **WHEN** a WebSocket connection is closed through any path (normal close, error, or janitor cleanup)
- **THEN** the IP connection count is decremented exactly once and no path shall decrement twice

#### Scenario: Janitor cleanup closes dead connections without double-decrementing
- **WHEN** the WebSocket janitor calls `cleanup_dead_connections`
- **THEN** dead connections are closed via their outgoing channel and their writer fiber handles the IP count decrement via `unregister_connection`

**Reason**: The previous implementation had `cleanup_dead_connections` directly decrement IP counts while writer fibers also called `unregister_connection`, causing counts to go negative and bypassing the per-IP limit.
**Migration**: The janitor now only closes channels and does not call `decrement_ip_count` directly.

### Requirement: WebSocket statistics are accurate
The system SHALL maintain accurate counts of messages sent, dropped, and send errors.

#### Scenario: Processed events reflect actual deliveries
- **WHEN** the EventBroadcaster processes a feed update event
- **THEN** `PROCESSED_EVENTS` is incremented exactly once per event delivered to a connected client

#### Scenario: Dropped events are not double-counted
- **WHEN** the event channel is full and an event is dropped
- **THEN** `DROPPED_EVENTS` is incremented exactly once and `PROCESSED_EVENTS` is not incremented for that event

**Reason**: `PROCESSED_EVENTS` was being incremented both when events were sent to the channel AND when they were broadcast to clients, double-counting all events.
**Migration**: Remove the increment from `notify_feed_update`; keep only the increment in the broadcast loop.

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