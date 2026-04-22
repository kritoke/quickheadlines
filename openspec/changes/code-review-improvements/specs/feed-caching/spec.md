## ADDED Requirements

### Requirement: FeedCache supports injection
The FeedCache class SHALL support dependency injection for testing.

#### Scenario: Custom cache provided
- **WHEN** FeedFetcher is initialized with custom FeedCache
- **THEN** fetcher uses the provided cache for all operations

#### Scenario: Singleton still available
- **WHEN** FeedCache.instance is called
- **THEN** returns default singleton instance

### Requirement: Cache interface is documented
The FeedCache public API SHALL be documented for implementors.

#### Scenario: Cache implements required interface
- **WHEN** custom cache is provided to FeedFetcher
- **THEN** cache must implement: get(url), add(feed_data), clear
