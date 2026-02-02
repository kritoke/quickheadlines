## MODIFIED Requirements

### Requirement: Consistent "Load More" Visibility
The system SHALL only display the "Load More" button for a feed if there are more items available to fetch from the backend. The `total_item_count` returned by the API MUST represent the total count of items stored in the persistent database for that feed, not just the count of items in the current response.

#### Scenario: Feed has more items in database
- **WHEN** the number of displayed items is less than the `total_item_count` (total items in DB)
- **THEN** the "Load More" button MUST be visible

#### Scenario: Feed is exhausted in database
- **WHEN** the number of displayed items is equal to or greater than the `total_item_count` (total items in DB)
- **THEN** the "Load More" button SHALL NOT be visible
