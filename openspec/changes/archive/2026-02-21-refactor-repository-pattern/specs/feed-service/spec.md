## ADDED Requirements

### Requirement: FeedService manages feed lifecycle
The system SHALL provide a FeedService that encapsulates business logic for feed operations.

#### Scenario: Get all feeds
- **WHEN** `FeedService.get_all_feeds` is called
- **THEN** returns all feeds from the repository

#### Scenario: Get feed with items
- **WHEN** `FeedService.get_feed_with_items(url, limit)` is called
- **THEN** returns feed data including its items up to the specified limit

#### Scenario: Refresh feed
- **WHEN** `FeedService.refresh_feed(url)` is called
- **THEN** triggers a fetch and updates the feed data in the repository

#### Scenario: Update feed colors
- **WHEN** `FeedService.update_feed_colors(url, bg, text)` is called
- **THEN** updates the header colors for the feed in the repository

#### Scenario: Cleanup orphaned feeds
- **WHEN** `FeedService.cleanup_orphaned_feeds(config_urls)` is called
- **THEN** removes feeds from the database that are not in the config URLs

### Requirement: FeedService manages ingestion lifecycle
The FeedService SHALL handle RSS/Atom source discovery, subscription management, and last_fetched updates.

#### Scenario: Update last fetched time on ingest
- **WHEN** new items are ingested for a feed
- **THEN** the service updates the last_fetched_at timestamp

#### Scenario: Discover feed source
- **WHEN** a feed URL is provided
- **THEN** the service attempts to parse RSS/Atom and extract metadata
