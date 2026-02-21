## ADDED Requirements

### Requirement: StoryService manages story operations
The system SHALL provide a StoryService that encapsulates business logic for story operations.

#### Scenario: Get timeline
- **WHEN** `StoryService.get_timeline(limit, offset, days)` is called
- **THEN** returns timeline items with pagination and cluster information

#### Scenario: Get feed items
- **WHEN** `StoryService.get_feed_items(url, limit, offset)` is called
- **THEN** returns stories for the specified feed with pagination

#### Scenario: Load more items
- **WHEN** `StoryService.load_more_items(url, limit, offset)` is called
- **THEN** returns additional items beyond the initial load

### Requirement: StoryService manages content graph
The StoryService SHALL handle article persistence, deduplication, and retrieving grouped news clusters.

#### Scenario: Persist new story
- **WHEN** a new story is detected during feed fetch
- **THEN** the service saves it to the repository with deduplication check

#### Scenario: Deduplicate story
- **WHEN** a story with duplicate title exists for the feed
- **THEN** the service skips persisting the duplicate

#### Scenario: Get clustered stories
- **WHEN** `StoryService.get_clusters` is called
- **THEN** returns news clusters with representative and related stories
