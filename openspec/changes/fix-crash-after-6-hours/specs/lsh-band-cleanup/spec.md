## ADDED Requirements

### Requirement: LSH bands cleaned up when items are deleted
The system SHALL remove LSH band entries from the lsh_bands table when their associated items are deleted, preventing unbounded table growth.

#### Scenario: Orphaned LSH bands removed during cleanup
- **WHEN** cleanup_old_articles is called
- **THEN** orphaned LSH bands (entries where item_id no longer exists in items table) are deleted

#### Scenario: LSH bands deleted with clustered items
- **WHEN** items with cluster_id are explicitly deleted
- **THEN** their associated LSH band entries are also deleted

### Requirement: LSH band cleanup during size-based cleanup
The system SHALL clean up LSH bands during aggressive cleanup when database size limit is approached.

#### Scenario: LSH bands cleaned when approaching size limit
- **WHEN** check_size_limit runs aggressive cleanup
- **THEN** orphaned LSH bands are removed as part of the cleanup process
