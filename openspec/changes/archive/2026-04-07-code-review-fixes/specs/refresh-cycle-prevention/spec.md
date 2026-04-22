## ADDED Requirements

### Requirement: Refresh cycle mutual exclusion
The system SHALL prevent overlapping refresh cycles to avoid resource exhaustion and inconsistent state.

#### Scenario: Refresh cycle in progress
- **WHEN** a refresh cycle is currently executing
- **AND** the scheduled time for the next refresh arrives
- **THEN** the next refresh is skipped (not queued, not overlapped)

#### Scenario: Refresh cycle completes before next scheduled time
- **WHEN** a refresh cycle completes
- **AND** the next scheduled time has not arrived yet
- **THEN** the next refresh happens at its scheduled time

#### Scenario: Long-running refresh
- **WHEN** a refresh cycle takes longer than the refresh interval
- **THEN** the system logs a warning about the slow refresh
- **AND** the next refresh is still skipped

### Requirement: Background cleanup isolation
Background cleanup tasks SHALL run independently of request handling without blocking.

#### Scenario: Cleanup takes a long time
- **WHEN** a background cleanup operation is running
- **AND** a new request comes in
- **THEN** the request is not blocked by the ongoing cleanup
