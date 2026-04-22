## ADDED Requirements

### Requirement: Atomic counter operations in HealthMonitor
The system SHALL use atomic operations for all counter fields in `HealthMonitor` to prevent race conditions in Crystal's M:N fiber scheduler.

#### Scenario: Cache hit counter increments atomically
- **WHEN** `HealthMonitor.record_cache_hit` is called from multiple fibers concurrently
- **THEN** the final counter value equals the total number of calls
- **AND** no increments are lost due to race conditions

#### Scenario: Cache miss counter increments atomically
- **WHEN** `HealthMonitor.record_cache_miss` is called from multiple fibers concurrently
- **THEN** the final counter value equals the total number of calls

#### Scenario: DB query count increments atomically
- **WHEN** `HealthMonitor.record_db_query` is called from multiple fibers concurrently
- **THEN** `@@db_query_count` is incremented correctly
- **AND** `@@db_query_times` appends each time without corruption

### Requirement: DB query times stored in thread-safe manner
The system SHALL store database query times in a thread-safe ring buffer.

#### Scenario: Query times accumulated without race
- **WHEN** multiple fibers call `record_db_query` concurrently
- **THEN** each query time is recorded in `@@db_query_times`
- **AND** the ring buffer limit of 100 entries is respected
- **AND** no duplicate entries or lost entries occur

### Requirement: CPU usage calculation is thread-safe
The system SHALL use atomic or properly synchronized access when calculating CPU usage across fiber context switches.

#### Scenario: CPU metrics calculated correctly
- **WHEN** `calculate_cpu_usage` is called
- **AND** other fibers are updating `@@last_cpu_time` and `@@last_check_time`
- **THEN** the calculation uses consistent pairs of values
- **AND** no torn reads occur
