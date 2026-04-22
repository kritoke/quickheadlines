## 1. StoryRepository CTE Deduplication

- [x] 1.1 Extract `cluster_info` CTE into a private `build_cluster_info_cte` method in StoryRepository
- [x] 1.2 Update `find_timeline_items` to use the shared CTE method
- [x] 1.3 Update `count_timeline_items` to use the shared CTE method

## 2. Favicon Hash Deduplication

- [x] 2.1 Extract `favicon_hash_for_url(url)` private method in FaviconStorage (from `save_favicon` logic)
- [x] 2.2 Update `FaviconStorage#get_or_fetch` to use `favicon_hash_for_url`
- [x] 2.3 Update `FaviconStorage#convert_data_uri` to use `favicon_hash_for_url`
- [x] 2.4 Update `FaviconSyncService#find_local_favicon` to use `FaviconStorage` shared hash method (may need to make it accessible)

## 3. Theme Text Normalization Consolidation

- [x] 3.1 Audit all 4 normalization implementations for subtle differences (ColorExtractor x2, ThemeHelper, FaviconSyncService)
- [x] 3.2 Consolidate into a single canonical method in ColorExtractor
- [x] 3.3 Update ThemeHelper to call ColorExtractor method
- [x] 3.4 Update FaviconSyncService#backfill_header_colors to call ColorExtractor method

## 4. Admin Clear Cache Simplification

- [x] 4.1 Remove raw DELETE SQL from `AdminController#handle_clear_cache`
- [x] 4.2 Delegate entirely to `FeedCache.clear_all`

## 5. URL Normalization Consolidation

- [x] 5.1 Standardize on `CacheUtils.normalize_feed_url` as the canonical wrapper
- [x] 5.2 Remove `normalize_url` from `ApiBaseController`, update callers to use `CacheUtils.normalize_feed_url`
- [x] 5.3 Update any remaining direct `UrlNormalizer.normalize` calls in controllers to use the wrapper

## 6. HeaderColorStore Query Helper

- [x] 6.1 Extract `find_feed_by_url(url)` private method with normalized-then-raw fallback in HeaderColorStore
- [x] 6.2 Update `update_header_colors` to use `find_feed_by_url`
- [x] 6.3 Update `load_theme` to use `find_feed_by_url`

## 7. Verification

- [x] 7.1 Run `just nix-build` and verify compilation succeeds
- [x] 7.2 Run `nix develop . --command crystal spec` and verify tests pass
