## ADDED Requirements

### Requirement: Clustering operations complete within timeout
The system SHALL ensure async_clustering operations do not hang indefinitely by using a timeout mechanism.

#### Scenario: Clustering completes successfully within timeout
- **WHEN** async_clustering processes all feeds before the timeout
- **THEN** StateStore.clustering is set to false after all feeds are processed

#### Scenario: Clustering times out
- **WHEN** async_clustering does not complete within 5 minutes
- **THEN** a warning log is emitted indicating timeout
- **AND** StateStore.clustering is set to false regardless

#### Scenario: Partial clustering completion logged
- **WHEN** clustering times out after completing N of M feeds
- **THEN** a warning log is emitted with the completion count "async_clustering timed out after N/M completions"

### Requirement: Clustering stuck detection
The system SHALL detect and reset clustering state if clustering appears stuck for an extended period.

#### Scenario: Clustering state reset after 4 hours
- **WHEN** clustering_start_time is set and Time.utc - clustering_start_time > 4 hours
- **THEN** clustering state is reset via HealthMonitor warning
