## ADDED Requirements

### Requirement: FeedRepository provides feed persistence operations
The system SHALL provide a FeedRepository class that handles all feed-related database operations, abstracting SQL from higher layers.

#### Scenario: Find all feeds
- **WHEN** `FeedRepository.find_all` is called
- **THEN** returns an array of all Feed entities from the database

#### Scenario: Find feed by URL
- **WHEN** `FeedRepository.find_by_url(url)` is called with a valid URL
- **THEN** returns the Feed entity if found, nil otherwise

#### Scenario: Find feed by URL pattern
- **WHEN** `FeedRepository.find_by_pattern(pattern)` is called
- **THEN** returns a Feed entity matching the normalized URL pattern

#### Scenario: Save feed
- **WHEN** `FeedRepository.save(feed)` is called
- **THEN** inserts or updates the feed and returns the saved entity

#### Scenario: Update last fetched time
- **WHEN** `FeedRepository.update_last_fetched(url, time)` is called
- **THEN** updates the last_fetched timestamp for the specified feed

#### Scenario: Update header colors
- **WHEN** `FeedRepository.update_header_colors(url, bg, text)` is called
- **THEN** updates the header_color and header_text_color for the feed

#### Scenario: Delete feed by URL
- **WHEN** `FeedRepository.delete_by_url(url)` is called
- **THEN** removes the feed and its associated items from the database

#### Scenario: Count items for feed
- **WHEN** `FeedRepository.count_items(url)` is called
- **THEN** returns the total number of items for the feed

### Requirement: StoryRepository provides story persistence operations
The system SHALL provide a StoryRepository class that handles all story-related database operations.

#### Scenario: Find all stories with pagination
- **WHEN** `StoryRepository.find_all(limit, offset)` is called
- **THEN** returns paginated array of Story entities

#### Scenario: Find story by ID
- **WHEN** `StoryRepository.find_by_id(id)` is called
- **THEN** returns the Story entity if found, nil otherwise

#### Scenario: Find stories by feed
- **WHEN** `StoryRepository.find_by_feed(feed_id, limit, offset)` is called
- **THEN** returns stories for the specified feed with pagination

#### Scenario: Save story
- **WHEN** `StoryRepository.save(story)` is called
- **THEN** inserts or updates the story and returns the saved entity

#### Scenario: Get timeline items
- **WHEN** `StoryRepository.find_timeline_items(limit, offset, days)` is called
- **THEN** returns timeline items with cluster information

#### Scenario: Count timeline items
- **WHEN** `StoryRepository.count_timeline_items(days)` is called
- **THEN** returns total count of items within the date range

#### Scenario: Check duplicate story
- **WHEN** `StoryRepository.deduplicate(feed_id, title)` is called
- **THEN** returns true if a story with same title exists for the feed

### Requirement: ClusterRepository provides cluster persistence operations
The system SHALL provide a ClusterRepository class for cluster-related database operations.

#### Scenario: Find all clusters
- **WHEN** `ClusterRepository.find_all` is called
- **THEN** returns all clusters with their representative and other items

#### Scenario: Find cluster items
- **WHEN** `ClusterRepository.find_items(cluster_id)` is called
- **THEN** returns all stories belonging to the cluster

#### Scenario: Assign cluster
- **WHEN** `ClusterRepository.assign_cluster(item_id, cluster_id)` is called
- **THEN** updates the cluster_id for the item

#### Scenario: Clear clustering metadata
- **WHEN** `ClusterRepository.clear_all_metadata` is called
- **THEN** removes all cluster_id and LSH band data

### Requirement: Controllers use Services only, Services use Repositories only
The system SHALL enforce layered architecture where Controllers cannot access Repositories or the database directly.

#### Scenario: Controller requests data
- **WHEN** an API endpoint is called
- **THEN** the Controller calls a Service method, never a Repository directly

#### Scenario: Service requests data
- **WHEN** a Service method needs data
- **THEN** the Service calls one or more Repository methods
