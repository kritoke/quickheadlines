## ADDED Requirements

### Requirement: Exponential backoff on feed fetch retries
The system SHALL use exponential backoff with a maximum delay when retrying failed feed fetches.

#### Scenario: Exponential backoff applied
- **WHEN** a feed fetch fails and retries are needed
- **AND** retry attempt 1 fails
- **THEN** the next retry waits `2^1 = 2` seconds
- **AND** retry attempt 2 fails
- **THEN** the next retry waits `2^2 = 4` seconds
- **AND** retry attempt 3 fails
- **THEN** the next retry waits `2^3 = 8` seconds

#### Scenario: Backoff capped at 60 seconds
- **WHEN** retry attempt 6 fails
- **AND** `2^6 = 64` seconds would be the backoff
- **THEN** the actual wait is capped at `60` seconds
- **AND** subsequent retries continue with 60 second delays

#### Scenario: Maximum 3 retries total
- **WHEN** a feed fetch has failed 3 times
- **AND** the fetch is attempted again
- **THEN** the system returns a cached or error result
- **AND** no further automatic retries occur for that fetch cycle

### Requirement: Linear backoff removed
The system SHALL NOT use linear backoff (e.g., `5 * retries`) for feed fetch retries.

#### Scenario: No linear backoff formula
- **WHEN** feed fetching retry logic is examined
- **THEN** there is no expression of the form `N * retries` where N is a constant delay
