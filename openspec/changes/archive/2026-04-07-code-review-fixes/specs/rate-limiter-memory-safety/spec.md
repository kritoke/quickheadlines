## ADDED Requirements

### Requirement: Rate limiter background cleanup isolation
Rate limiter cleanup SHALL run in a dedicated background fiber and SHALL NOT block request handling.

#### Scenario: Cleanup fiber runs independently
- **WHEN** the background cleanup fiber is running
- **AND** a request comes in
- **THEN** the request is processed without waiting for cleanup to complete

#### Scenario: Cleanup scheduled at regular intervals
- **WHEN** 60 seconds have elapsed since last cleanup
- **THEN** the cleanup fiber removes entries with no recent requests

#### Scenario: Cleanup does not block allowed check
- **WHEN** allowed? is called
- **THEN** the method returns immediately without waiting for or performing cleanup
