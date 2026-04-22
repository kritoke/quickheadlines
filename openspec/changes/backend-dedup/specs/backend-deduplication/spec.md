## ADDED Requirements

### Requirement: StoryRepository uses shared CTE builder
The identical `cluster_info` CTE SHALL be defined in a single private method and reused by both `find_timeline_items` and `count_timeline_items`.

#### Scenario: CTE defined once
- **WHEN** StoryRepository is compiled
- **THEN** the `cluster_info` CTE SQL string exists in exactly one method
- **THEN** both `find_timeline_items` and `count_timeline_items` call the shared method

### Requirement: Favicon hash computation uses shared method
SHA256 hash computation for favicon URLs SHALL exist in a single `favicon_hash_for_url` private method in `FaviconStorage`. `FaviconSyncService` SHALL call this method instead of computing its own hash.

#### Scenario: Hash computed in one place
- **WHEN** a favicon hash is needed
- **THEN** it is computed via `FaviconStorage`'s shared method
- **THEN** `FaviconSyncService#find_local_favicon` uses the shared method

### Requirement: Theme text normalization consolidated
Theme text normalization logic SHALL be consolidated into `ColorExtractor` as the canonical location. `ThemeHelper` and `FaviconSyncService` SHALL call `ColorExtractor` methods instead of reimplementing normalization.

#### Scenario: Single normalization source
- **WHEN** theme text values need normalization
- **THEN** the logic is in `ColorExtractor`
- **THEN** `ThemeHelper` and `FaviconSyncService` call `ColorExtractor` methods

### Requirement: Admin clear_cache delegates to FeedCache
`AdminController#handle_clear_cache` SHALL NOT execute raw SQL DELETE statements. It SHALL delegate entirely to `FeedCache.clear_all`.

#### Scenario: No raw SQL in admin clear_cache
- **WHEN** `AdminController#handle_clear_cache` is called
- **THEN** no raw SQL DELETE statements are executed directly
- **THEN** `FeedCache.clear_all` handles all cleanup

### Requirement: URL normalization uses single canonical wrapper
`CacheUtils.normalize_feed_url` SHALL be the single canonical URL normalization wrapper. Duplicate wrappers in `ApiBaseController` and `Utils` SHALL be removed.

#### Scenario: Single normalization entry point
- **WHEN** URL normalization is needed in controllers or stores
- **THEN** `CacheUtils.normalize_feed_url` is called
- **THEN** no duplicate `normalize_url` wrapper exists in `ApiBaseController`

### Requirement: HeaderColorStore uses shared query helper
The pattern of "query by normalized URL, fallback to raw URL" SHALL be extracted into a shared `find_feed_by_url` method in `HeaderColorStore`.

#### Scenario: Shared fallback query
- **WHEN** `HeaderColorStore` needs to look up a feed by URL
- **THEN** the normalized-then-raw fallback pattern is in one method
- **THEN** `update_header_colors` and `load_theme` both use the shared method
