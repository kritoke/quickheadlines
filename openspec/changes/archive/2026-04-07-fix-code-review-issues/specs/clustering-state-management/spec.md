## ADDED Requirements

### Requirement: Unified clustering state mutex
The system SHALL use a single mutex for all clustering state access to prevent race conditions between readers and writers.

#### Scenario: Clustering started while checking status
- **WHEN** one fiber calls clustering? while another fiber calls start_clustering_if_idle
- **THEN** the read and write operations do not race
- **AND** clustering? always returns a consistent value

#### Scenario: Clustering flag consistency
- **WHEN** refresh_all sets clustering to true via StateStore.update
- **AND** start_clustering_if_idle is called concurrently
- **THEN** both use the same mutex for the clustering field
- **AND** only one fiber actually starts clustering

### Requirement: Crash-safe clustering job counter
The system SHALL use channel-based completion tracking for clustering jobs to ensure the clustering flag is always reset, even if some fibers crash.

#### Scenario: All jobs complete normally
- **WHEN** all clustering jobs finish successfully
- **THEN** the parent fiber receives one completion signal per job
- **AND** clustering is set to false after all signals are received

#### Scenario: Job fiber crashes
- **WHEN** a clustering job fiber crashes before completing
- **THEN** the parent fiber still waits for exactly N completions (where N is the original feed count)
- **AND** if a fiber crashes without sending completion, the parent waits forever (safety mechanism)

#### Scenario: Duplicate clustering prevented
- **WHEN** clustering is already in progress
- **THEN** start_clustering_if_idle returns false
- **AND** the caller does not start additional clustering work

### Requirement: Clustering stuck detection
The system SHALL detect when clustering appears stuck and automatically reset the clustering flag.

#### Scenario: Clustering runs longer than 4 hours
- **WHEN** clustering has been running for more than 4 hours
- **THEN** the scheduler logs a warning and resets the clustering flag to false
- **AND** subsequent clustering runs are allowed to start
