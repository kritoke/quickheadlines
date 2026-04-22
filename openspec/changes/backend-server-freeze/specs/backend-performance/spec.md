## ADDED Requirements

### Requirement: Server remains responsive under load
The HTTP server SHALL remain responsive to incoming requests for extended periods (24+ hours). No single background task SHALL block the event loop long enough to cause request timeouts.

#### Scenario: Server handles favicon requests during feed refresh
- **WHEN** 50+ favicon requests arrive simultaneously while feed refresh is running
- **THEN** all requests complete within 5 seconds and the server remains responsive

#### Scenario: Server stays alive after startup
- **WHEN** the server starts up and completes favicon sync
- **THEN** the server continues responding to HTTP requests indefinitely

### Requirement: Favicon responses use browser caching
All favicon responses SHALL include `Cache-Control` headers so browsers cache them and avoid re-requesting on every page load.

#### Scenario: Browser caches favicons
- **WHEN** a favicon is served via `/favicons/{hash}.{ext}`
- **THEN** the response includes `Cache-Control: public, max-age=604800, immutable`

### Requirement: Favicon serving uses in-memory cache
The favicon endpoint SHALL use an in-memory cache to avoid repeated disk I/O for the same favicon file.

#### Scenario: Repeated favicon request served from memory
- **WHEN** the same favicon is requested 100 times
- **THEN** only the first request reads from disk; subsequent requests use the in-memory cache

### Requirement: Background tasks yield during blocking operations
Long-running background tasks (favicon sync, feed refresh) SHALL yield to the event loop periodically to allow HTTP request processing.

#### Scenario: Favicon sync yields during HTTP fetches
- **WHEN** favicon sync downloads multiple favicons sequentially
- **THEN** each fetch yields control back to the event loop between iterations
