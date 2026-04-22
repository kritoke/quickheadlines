## ADDED Requirements

### Requirement: Favicon sync mutex scope minimization
The system SHALL minimize the duration that `@mutex` is held during `sync_favicon_paths`, performing all I/O, external fetches, and database queries outside the lock.

#### Scenario: Mutex only guards file write
- **WHEN** `sync_favicon_paths` is called
- **THEN** all color extraction, HTTP fetching, and database reads occur before acquiring `@mutex`
- **AND** `@mutex` is only held during the check-and-write to filesystem

#### Scenario: Concurrent feed cache reads during sync
- **WHEN** `sync_favicon_paths` is running
- **AND** another fiber calls `FeedCache#get` or `FeedCache#add`
- **THEN** that operation is not blocked by the favicon sync mutex

#### Scenario: Slow HTTP fetch does not block cache
- **WHEN** a favicon requires fetching from `google.com/s2/favicons`
- **AND** the fetch takes 5 seconds
- **THEN** `FeedCache` operations on other feeds are not blocked during those 5 seconds

### Requirement: Favicon sync logs progress
The system SHALL log progress during `sync_favicon_paths` to aid debugging slow sync operations.

#### Scenario: Backfill progress logged
- **WHEN** `sync_favicon_paths` is processing backfills
- **THEN** a summary is logged: `"[Cache] Backfill summary: local=N, google=N, missing=N"`
- **AND** individual backfill results are logged when completed
