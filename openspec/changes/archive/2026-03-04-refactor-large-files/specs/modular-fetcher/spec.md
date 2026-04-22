## ADDED Requirements

### Requirement: Fetcher modules SHALL be organized in src/fetcher/ directory
The fetcher code SHALL be split into focused modules under `src/fetcher/` for better maintainability.

#### Scenario: Favicon module exists
- **WHEN** developer requires `./fetcher/favicon`
- **THEN** system provides `FaviconHelper`, `FaviconCache`, `fetch_favicon_uri`, `valid_image?`

#### Scenario: Feed fetcher module exists
- **WHEN** developer requires `./fetcher/feed_fetcher`
- **THEN** system provides `fetch_feed`, `load_feeds_from_cache`

#### Scenario: Refresh loop module exists
- **WHEN** developer requires `./fetcher/refresh_loop`
- **THEN** system provides `refresh_all`, `async_clustering`, `compute_cluster_for_item`, `process_feed_item_clustering`, `start_refresh_loop`

### Requirement: Backward compatibility SHALL be maintained for fetcher requires
Existing code requiring `./fetcher` SHALL continue to work without modifications.

#### Scenario: Legacy require path works
- **WHEN** code has `require "./fetcher"`
- **THEN** all fetcher functions and classes remain accessible

#### Scenario: No behavioral changes
- **WHEN** fetcher modules are split
- **THEN** all existing tests pass without modification
