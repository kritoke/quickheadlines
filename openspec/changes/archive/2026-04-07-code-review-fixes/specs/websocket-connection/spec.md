## ADDED Requirements

### Requirement: WebSocket registration exception safety
The system SHALL guarantee proper cleanup of IP counts when WebSocket registration fails mid-operation.

#### Scenario: Registration fails during IP count increment
- **WHEN** WebSocket registration begins
- **AND** an exception occurs after incrementing IP count but before adding connection
- **THEN** the IP count is decremented (cleaned up)

#### Scenario: Registration fails during connection creation
- **WHEN** WebSocket registration begins
- **AND** an exception occurs during any step before connection is fully added
- **THEN** no orphaned IP counts remain in the tracking hash

### Requirement: Single mutex protection for registration
All state modifications during WebSocket registration SHALL be protected by a single mutex to prevent partial state visibility.

#### Scenario: Concurrent registration attempts
- **WHEN** multiple WebSocket connections are being registered simultaneously
- **THEN** each registration's state modifications are atomic
- **AND** no intermediate states are visible to other registrations
