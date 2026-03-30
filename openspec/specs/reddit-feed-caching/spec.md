# reddit-feed-caching Specification

## Purpose
TBD - created by archiving change reddit-feed-caching. Update Purpose after archive.
## Requirements
### Requirement: Reddit feeds support HTTP caching headers
The system SHALL send If-None-Match and If-Modified-Since headers when fetching Reddit feeds if cached etag/last_modified values are available.

#### Scenario: Initial fetch with no cache
- **WHEN** fetching a Reddit feed for the first time (no previous_data)
- **THEN** no caching headers are sent
- **AND** the response is parsed normally and etag/last_modified are captured

#### Scenario: Subsequent fetch with cached etag
- **WHEN** fetching a Reddit feed with a cached etag value
- **THEN** If-None-Match header is sent with the cached etag value
- **AND** If-Modified-Since header is sent with the cached last_modified value (if available)

### Requirement: Reddit feeds handle 304 Not Modified responses
The system SHALL return cached data when Reddit API returns 304 Not Modified, with updated cache headers.

#### Scenario: Reddit returns 304 Not Modified
- **WHEN** Reddit API returns HTTP 304
- **THEN** the previous cached FeedData is returned
- **AND** the etag/last_modified are updated from response headers (if present)
- **AND** debug log indicates cache hit

#### Scenario: Reddit returns 200 with new content
- **WHEN** Reddit API returns HTTP 200 with new content
- **THEN** new items are parsed and returned
- **AND** new etag/last_modified headers are captured from response
- **AND** debug log indicates fresh fetch

### Requirement: Reddit RSS fallback supports caching
The system SHALL also support caching headers when fetching Reddit via RSS fallback.

#### Scenario: RSS fallback with caching headers
- **WHEN** JSON fetch fails and RSS fallback is used
- **THEN** caching headers are sent to RSS endpoint if available
- **AND** 304 responses are handled the same way as JSON

