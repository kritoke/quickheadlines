## ADDED Requirements

### Requirement: Per-Connection Writer Fiber
Each WebSocket connection SHALL have a dedicated writer fiber with a bounded outgoing Channel to serialize all writes and provide backpressure.

#### Scenario: Message queued for delivery
- **WHEN** Server broadcasts a feed update to a connected client
- **THEN** The message SHALL be queued to the connection's outgoing Channel
- **AND** The writer fiber SHALL send the message via WebSocket in FIFO order

#### Scenario: Channel full due to slow client
- **WHEN** The outgoing Channel is full (default: 10 messages)
- **AND** A new broadcast message arrives
- **THEN** The oldest message in the queue SHALL be dropped
- **AND** A counter SHALL be incremented for monitoring

#### Scenario: Connection closed while messages queued
- **WHEN** Client disconnects while messages are queued
- **THEN** The writer fiber SHALL exit
- **AND** All queued messages SHALL be discarded
- **AND** Connection SHALL be removed from SocketManager

### Requirement: Thread-Safe Broadcast
The SocketManager broadcast method SHALL NOT hold the connection mutex during I/O operations.

#### Scenario: Broadcast in progress while client connects
- **WHEN** A broadcast is iterating over connections
- **AND** A new client connects
- **THEN** The new client SHALL NOT receive the current broadcast
- **AND** The new client SHALL receive subsequent broadcasts

#### Scenario: Broadcast in progress while client disconnects
- **WHEN** A broadcast is iterating over connections
- **AND** A client disconnects
- **THEN** The disconnected client SHALL be removed after the broadcast completes
- **AND** The iteration SHALL not be affected by the removal

### Requirement: Error Handling
SocketManager SHALL log detailed error information including exception type and backtrace.

#### Scenario: Send fails due to network error
- **WHEN** ws.send() raises an exception
- **THEN** The exception class SHALL be logged
- **AND** The exception message SHALL be logged
- **AND** The connection SHALL be marked for removal
