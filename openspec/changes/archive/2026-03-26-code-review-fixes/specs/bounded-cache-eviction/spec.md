## ADDED Requirements

### Requirement: Bounded Cache for Color Extraction

The ColorExtractor extraction cache SHALL have a maximum size to prevent unbounded memory growth.

#### Scenario: Cache respects maximum size
- **WHEN** the cache reaches `ColorExtractor::MAX_CACHE_SIZE`
- **THEN** the least recently used entries SHALL be evicted
- **AND** new entries SHALL be added without unbounded growth

#### Scenario: Cache default size is 1000 entries
- **WHEN** ColorExtractor is initialized
- **THEN** the default maximum cache size SHALL be 1000 entries

#### Scenario: Cache entries have expiration
- **WHEN** a cache entry is older than 7 days
- **THEN** it SHALL be considered for eviction on next access
- **AND** expired entries SHALL be removed before new entries are added

### Requirement: Health Monitor Cleanup

The HealthMonitor feed_health hash SHALL remove entries for feeds that no longer exist in configuration.

#### Scenario: Orphaned health entries cleaned on refresh
- **WHEN** a feed is removed from feeds.yml
- **AND** the application refreshes
- **THEN** the health entry for that feed SHALL be removed from `@@feed_health`
- **AND** memory SHALL not grow indefinitely from deleted feeds
