## ADDED Requirements

### Requirement: Timeline loads efficiently
The timeline endpoint SHALL load items without making individual database queries per item.

#### Scenario: Timeline returns data
- **WHEN** client requests `/api/timeline?limit=100`
- **THEN** response includes up to 100 timeline items
- **THEN** database makes at most 3 queries total (not N+1)

#### Scenario: Timeline with cluster info loads efficiently
- **WHEN** client requests `/api/timeline` with clustering enabled
- **THEN** cluster information is fetched in batch, not per item

### Requirement: Timeline returns sorted data
The timeline endpoint SHALL return items sorted by publication date descending.

#### Scenario: Timeline sorted correctly
- **WHEN** client requests `/api/timeline`
- **THEN** items are sorted with newest first
- **THEN** no additional sorting is needed on client side

### Requirement: Timeline caching
Frequently requested timeline pages SHALL be cached to reduce load.

#### Scenario: Same timeline request returns cached data
- **WHEN** client requests `/api/timeline?limit=100&offset=0` twice within 30 seconds
- **THEN** second request returns in less than 50ms
