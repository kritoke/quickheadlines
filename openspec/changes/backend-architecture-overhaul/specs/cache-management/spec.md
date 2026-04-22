## ADDED Requirements

### Requirement: LRU Cache with Size Limits
The system SHALL implement LRU cache with configurable size limits.

#### Scenario: Cache reaches size limit
- **WHEN** cache exceeds max size
- **THEN** least recently used entries are evicted

#### Scenario: Cache miss
- **WHEN** requested item not in cache
- **THEN** item is fetched and added to cache

### Requirement: Cache Memory Monitoring
The system SHALL monitor cache memory usage and expose metrics.

#### Scenario: Check cache metrics
- **WHEN** health metrics are requested
- **THEN** cache hit/miss ratios and memory usage are included

### Requirement: HTTP Connection Pooling
The system SHALL use HTTP client connection pooling.

#### Scenario: Multiple requests to same host
- **WHEN** multiple requests are made to the same host
- **THEN** connections are reused from the pool
