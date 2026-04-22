## ADDED Requirements

### Requirement: Link-based item deduplication
The system SHALL use the combination of feed_id and link for deduplicating feed items, not the item title.

#### Scenario: Same title different links are not duplicates
- **WHEN** two items have the same title but different links within the same feed
- **THEN** both items are inserted into the database
- **AND** no items are skipped due to title similarity

#### Scenario: Same link same title is a duplicate
- **WHEN** an item with the same feed_id and link already exists
- **THEN** INSERT OR IGNORE prevents insertion of the duplicate
- **AND** the existing item is preserved

#### Scenario: Title-based false positives prevented
- **WHEN** a feed has multiple "Security Update" articles with different URLs
- **THEN** all articles are stored (not silently dropped)
- **AND** each is accessible by its unique link

### Requirement: Batch insert efficiency
The system SHALL use batched INSERT OR IGNORE for efficient bulk item insertion without title-based pre-filtering.

#### Scenario: Large feed fetch inserts efficiently
- **WHEN** fetching a feed with 100+ new items
- **THEN** items are inserted in batches of 50
- **AND** duplicate links are automatically skipped by the database constraint

#### Scenario: Items with existing links updated
- **WHEN** an item has a link that exists but different metadata (e.g., comment_url)
- **THEN** the existing item's metadata is updated via batch_update
