## ADDED Requirements

### Requirement: Timeline query uses composite indexes
The database MUST have composite indexes that enable efficient timeline queries with clustering logic.

#### Scenario: Indexes exist on first startup
- **GIVEN** a fresh database with no indexes
- **WHEN** the application starts and `ensure_indexes` is called
- **THEN** the following indexes MUST be created:
  - `idx_items_timeline` on `(pub_date DESC, id DESC, cluster_id)`
  - `idx_items_cluster_rep` on `(cluster_id, id)`
  - `idx_items_feed_timeline` on `(feed_id, pub_date DESC, id DESC)`

#### Scenario: Index creation is idempotent
- **GIVEN** indexes already exist from previous startup
- **WHEN** `ensure_indexes` is called again
- **THEN** the operation MUST complete without error (using `CREATE INDEX IF NOT EXISTS`)

### Requirement: Timeline query structure is optimized
The timeline query MUST use an efficient SQL structure that minimizes correlated subqueries.

#### Scenario: Query returns only cluster representatives
- **GIVEN** items in the database with various cluster assignments
- **WHEN** the timeline query executes
- **THEN** only representative items (one per cluster) SHALL be returned
- **AND** non-representative items SHALL be excluded

#### Scenario: Query returns cluster size for representatives
- **GIVEN** clustered items in the database
- **WHEN** the timeline query returns representative items
- **THEN** each representative item SHALL include the correct cluster size
- **AND** non-representative items SHALL have cluster_size = 0 or NULL

#### Scenario: Query performance meets target
- **GIVEN** a database with 5000 items and 500 clusters
- **WHEN** timeline query is executed with limit=500, offset=0
- **THEN** query MUST complete in under 500ms

### Requirement: Query returns same results as original
The optimized query MUST produce identical results to the original query implementation.

#### Scenario: Timeline returns items in correct order
- **GIVEN** items with various pub_dates
- **WHEN** timeline query is executed
- **THEN** items SHALL be ordered by pub_date DESC, id DESC (newest first)

#### Scenario: Timeline respects date filter
- **GIVEN** items with pub_dates spanning multiple days
- **WHEN** timeline query is executed with days=7 parameter
- **THEN** only items from the last 7 days SHALL be returned

### Requirement: LSH band search index exists
The database MUST have an index for efficient LSH band lookups used in clustering.

#### Scenario: LSH index exists for clustering
- **GIVEN** a fresh database
- **WHEN** the application starts
- **THEN** index `idx_lsh_band_search` on `(band_index, band_hash)` MUST be created
