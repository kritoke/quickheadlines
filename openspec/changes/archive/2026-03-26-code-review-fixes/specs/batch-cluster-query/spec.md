## ADDED Requirements

### Requirement: Batch Fetch Cluster Data for Timeline

The timeline API SHALL fetch cluster data for all items in a single batch query rather than per-item queries.

#### Scenario: Timeline loads cluster info in batch
- **WHEN** the timeline API is called with N items
- **THEN** cluster_id lookup for all items SHALL use a single query with `WHERE id IN (...)`
- **AND** cluster sizes SHALL be fetched in a single batch query
- **AND** representative status SHALL be fetched in a single batch query
- **AND** total database queries for cluster data SHALL be at most 3 regardless of item count

#### Scenario: Timeline query performance bounded
- **WHEN** the timeline API is called with 100 items
- **THEN** the total number of database queries for cluster data SHALL NOT exceed 10
- **AND** query time SHALL be O(1) with respect to item count, not O(N)

### Requirement: Timeline Items Sorted by Publication Date

The timeline API SHALL return items sorted by publication date descending.

#### Scenario: Items sorted correctly
- **WHEN** the timeline API returns items
- **THEN** items SHALL be ordered by `pub_date DESC, id DESC`
- **AND** clustering information SHALL be attached correctly to each item
