## ADDED Requirements

### Requirement: Dedicated Feeds Store
The application SHALL provide a dedicated Svelte 5 store for managing feeds state that can be shared across components.

#### Scenario: Feeds store initialization
- **WHEN** the application loads
- **THEN** the feeds store SHALL initialize with empty feeds array, loading state, and error state

#### Scenario: Feeds store loads feeds
- **WHEN** `feedsStore.loadFeeds(tab)` is called
- **THEN** the store SHALL fetch feeds from the API and update its state
- **AND** the store SHALL set loading to true during fetch
- **AND** the store SHALL set loading to false after fetch completes

#### Scenario: Feeds store handles errors
- **WHEN** the API returns an error
- **THEN** the store SHALL capture the error message
- **AND** the store SHALL make the error available to all subscribed components

### Requirement: Dedicated Timeline Store
The application SHALL provide a dedicated Svelte 5 store for managing timeline state.

#### Scenario: Timeline store initialization
- **WHEN** the timeline page loads
- **THEN** the timeline store SHALL initialize with empty items array and pagination state

#### Scenario: Timeline store loads more items
- **WHEN** `timelineStore.loadMore()` is called
- **THEN** the store SHALL append new items to the existing items array
- **AND** the store SHALL update the offset for pagination

### Requirement: Dedicated Config Store
The application SHALL provide a dedicated Svelte 5 store for managing configuration state.

#### Scenario: Config store fetches configuration
- **WHEN** `configStore.load()` is called
- **THEN** the store SHALL fetch config from the API
- **AND** the store SHALL expose refresh_minutes and debug settings

#### Scenario: Config is accessible globally
- **WHEN** any component subscribes to the config store
- **THEN** the component SHALL receive the current configuration values

### Requirement: Cache Store with TTL
The application SHALL provide a cache store with time-to-live expiration.

#### Scenario: Cache stores data with TTL
- **WHEN** `cacheStore.set(key, value, ttl)` is called
- **THEN** the value SHALL be stored with an expiration timestamp
- **AND** the value SHALL remain accessible until TTL expires

#### Scenario: Cache returns expired data indicator
- **WHEN** accessing a key past its TTL
- **THEN** the cache SHALL indicate the data is stale
- **AND** the cache SHALL allow automatic re-fetch

### Requirement: Store Composition
Stores SHALL be composable to allow sharing state between related features.

#### Scenario: Feeds store updates on WebSocket message
- **WHEN** a WebSocket message of type 'feed_update' is received
- **THEN** the feeds store SHALL automatically reload feeds
- **AND** components subscribed to the store SHALL receive updates
