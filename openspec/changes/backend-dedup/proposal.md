## Why

The same logic is duplicated across 4+ locations in several areas: CTE query construction in StoryRepository, favicon SHA256 hash computation in FaviconStorage, theme text normalization across ColorExtractor/ThemeHelper/FaviconSyncService, URL normalization wrappers, header color store query patterns, and admin cache clearing logic. When one copy is fixed but not others, bugs emerge. Consolidating duplicated logic into shared methods reduces maintenance burden and eliminates inconsistency.

## What Changes

- Extract shared `cluster_info` CTE builder in `StoryRepository` into a private method
- Extract `favicon_hash_for_url(url)` private method in `FaviconStorage`
- Consolidate theme text normalization into a single shared utility method
- Remove `AdminController#handle_clear_cache` raw DELETE SQL, delegate to `FeedCache.clear_all`
- Consolidate URL normalization: standardize on `CacheUtils.normalize_feed_url`, remove duplicates
- Extract `HeaderColorStore.find_feed_by_url(url)` for the normalized-then-raw fallback pattern

## Capabilities

### New Capabilities
- `backend-deduplication`: Shared utility methods replacing duplicated logic across services, repositories, stores, and controllers

### Modified Capabilities

## Impact

- **Repositories**: `story_repository.cr` (shared CTE method)
- **Storage**: `favicon_storage.cr` (shared hash method), `header_color_store.cr` (shared query method)
- **Services**: `favicon_sync_service.cr` (use shared hash), `clustering_service.cr` (use shared theme normalization)
- **Fetcher**: `theme_helper.cr`, `color_extractor.cr` (shared normalization)
- **Controllers**: `admin_controller.cr` (simplified clear_cache), `api_base_controller.cr` (use shared normalization)
- **Utils**: `cache_utils.cr` (becomes canonical URL normalizer), `utils.cr` (remove duplicate wrapper)
