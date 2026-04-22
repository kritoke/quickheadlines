# timeline-pagination Specification

## MODIFIED Requirements

### Requirement: Pagination count reflects visible items only
The `count_timeline_items` function SHALL return a count that matches the actual number of items visible in the timeline, accounting for cluster representative filtering.

#### Scenario: Timeline with clustered items
- **WHEN** the timeline contains items where some belong to clusters
- **THEN** `count_timeline_items` returns only the count of cluster representatives plus unclustered items
- **AND** the returned count matches what `find_timeline_items` would return if it were not paginated

#### Scenario: Timeline count matches visible items with tab filter
- **WHEN** `count_timeline_items` is called with a tab filter
- **THEN** the count reflects only items from feeds belonging to that tab that are also cluster representatives

#### Scenario: has_more correctly indicates remaining items
- **WHEN** `get_timeline` computes `has_more = offset + limit < total_count`
- **THEN** `has_more = true` if and only if there are actually more visible (representative) items beyond the current page

**Reason**: Previously `count_timeline_items` counted all items matching the date/tab filter, including non-representative cluster members. But the timeline only shows representatives, making pagination calculations incorrect.
**Migration**: Apply the same `cluster_info` CTE and representative filter used in `find_timeline_items` to the count query.

### Requirement: Timeline items are sorted by publication date descending
The system SHALL return timeline items ordered by `pub_date DESC, id DESC` with null pub_dates sorted last.

#### Scenario: Items with various publication dates
- **WHEN** the timeline contains items with different publication dates
- **THEN** items are returned in descending order from newest to oldest

#### Scenario: Items with null publication dates
- **WHEN** some items have no publication date
- **THEN** those items appear at the end of the timeline, sorted by `id DESC` among themselves

### Requirement: Timeline respects day filtering
The system SHALL filter items by the specified number of days back from the current time.

#### Scenario: Filter by 7 days
- **WHEN** `days_back` is set to 7
- **THEN** only items published within the last 7 days (or with null pub_date) are returned