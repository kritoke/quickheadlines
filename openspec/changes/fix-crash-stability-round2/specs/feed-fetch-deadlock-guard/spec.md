## ADDED Requirements

### Requirement: Feed fetch channel receive has timeout
The system SHALL timeout on channel.receive in fetch_feeds_concurrently to prevent permanent deadlock.

#### Scenario: Feed fetch completes within timeout
- **WHEN** all spawned fibers send their results before timeout
- **THEN** all feed data is collected normally

#### Scenario: Feed fetch times out on stuck fiber
- **WHEN** a spawned fiber fails without sending to the channel
- **THEN** the main fiber times out after 5 minutes and continues with available results

#### Scenario: Error logged on timeout
- **WHEN** feed fetch times out
- **THEN** a warning is logged with the number of completed vs expected results

### Requirement: Spawned fibers always send to channel
The system SHALL ensure spawned fibers in fetch_feeds_concurrently always send to the channel, even on error.

#### Scenario: Fiber sends nil on exception
- **WHEN** a spawned fiber raises an exception during fetch_feed
- **THEN** nil is sent to the channel in the ensure block

### Requirement: Async clustering concurrency guard
The system SHALL prevent concurrent async_clustering executions.

#### Scenario: Clustering skipped when already running
- **WHEN** async_clustering is called while StateStore.clustering is true
- **THEN** the call returns immediately without spawning new fibers
