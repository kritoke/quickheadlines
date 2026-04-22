## ADDED Requirements

### Requirement: LSH Candidate Set Bounding

The LSH candidate search SHALL return a bounded set of candidates to prevent memory exhaustion.

#### Scenario: Large candidate set is truncated
- **WHEN** `find_lsh_candidates` finds more than `MAX_LSH_CANDIDATES` candidates
- **THEN** only the first `MAX_LSH_CANDIDATES` are returned
- **AND** the returned set size does not exceed the configured maximum

#### Scenario: Small candidate set is unchanged
- **WHEN** `find_lsh_candidates` finds fewer than `MAX_LSH_CANDIDATES` candidates
- **THEN** all candidates are returned
- **AND** no truncation occurs

### Requirement: Bounded Batch Processing

Batch insert operations SHALL process items in bounded chunks.

#### Scenario: Large item batch is chunked
- **WHEN** `batch_insert` receives more than 50 items
- **THEN** items are processed in slices of 50
- **AND** each chunk is a separate database transaction

### Requirement: Memory-Bounded Refresh

The refresh loop SHALL have bounded memory allocation for feed data.

#### Scenario: Concurrent feed fetching is semaphored
- **WHEN** `fetch_feeds_concurrently` processes multiple feeds
- **THEN** at most `CONCURRENCY` (8) feeds are fetched simultaneously
- **AND** no unbounded channel growth occurs
