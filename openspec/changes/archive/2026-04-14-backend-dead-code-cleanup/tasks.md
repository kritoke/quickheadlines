## 1. Delete Entire Dead Files

- [x] 1.1 Delete `src/services/feed_service.cr`
- [x] 1.2 Delete `src/dtos/feed_dto.cr`
- [x] 1.3 Delete `src/dtos/status_dto.cr`
- [x] 1.4 Delete `src/services/feed_state.cr`
- [x] 1.5 Delete `src/result.cr`

## 2. Remove Dead Code from application.cr Requires

- [x] 2.1 Remove `require` for deleted files (`feed_service`, `status_dto`, `feed_dto`, `result`)
- [x] 2.2 Verify build: `just nix-build`

## 3. Remove Dead DTOs from api_responses.cr

- [x] 3.1 Remove `VersionResponse` class (`src/dtos/api_responses.cr:180-188`)
- [x] 3.2 Remove `ApiErrorResponse` class (`src/dtos/api_responses.cr:190-197`)
- [x] 3.3 Verify build: `just nix-build`

## 4. Remove Dead Models

- [x] 4.1 Remove `TimelineItem` record from `src/models.cr`
- [x] 4.2 Remove `Domain::FeedItem` record from `src/domain/items.cr` (keep `Domain::TimelineEntry`)
- [x] 4.3 Verify build: `just nix-build`

## 5. Remove Dead Result-type Methods from Live Files

- [x] 5.1 Remove `*_result` methods from `src/repositories/feed_repository.cr` (`find_last_fetched_time_result`, `find_by_url_result`, `find_by_pattern_result`, `find_with_items_result`, `find_with_items_slice_result`)
- [x] 5.2 Remove `*_result` methods from `src/storage/feed_cache.cr` (`get_result`, `get_fetched_time_result`)
- [x] 5.3 Verify build: `just nix-build`

## 6. Remove Dead Methods from ApiBaseController

- [x] 6.1 Remove `feed_service` property and private method from `src/controllers/api_base_controller.cr`
- [x] 6.2 Verify build: `just nix-build`

## 7. Remove Dead Global Functions

- [x] 7.1 Remove dead functions from `src/utils.cr`: `try_https_first`, `create_client`, `parse_time`, `relative_time`, `current_date_fallback`, `last_updated_format`, `resolve_url`, `Utils.validate_feed_url`, `Utils.validate_proxy_host`
- [x] 7.2 Remove dead functions from `src/parser.cr`: `parse_feed()` (deleted entire file)
- [x] 7.3 Remove dead functions from `src/config/loader.cr`: `file_mtime`, `find_default_config`, `parse_config_arg`
- [x] 7.4 Remove dead functions from `src/config/github_sync.cr`: `detect_github_repo`, `fetch_github_config`, `download_github_config` (deleted entire file)
- [x] 7.5 Remove dead function from `src/storage/cache_utils.cr`: `get_db`
- [x] 7.6 Remove dead functions from `src/storage/database.cr`: `check_db_integrity`, `repopulate_database` (and `FeedRestoreConfig` struct)
- [x] 7.7 Verify build: `just nix-build`

## 8. Remove Dead ColorExtractor Methods

- [x] 8.1 Remove 16 unreachable methods from `src/color_extractor.cr` (kept `extract_theme_colors` and caching logic; removed accessibility, theme_detector, correct_theme_json, fix_text_colors, check_text_accessibility, rgb_from_array, parse_text_to_hash, parse_color_to_rgb, parse_rgb_notation, parse_hex_color, upgrade_theme_json, parse_theme_json, fix_and_parse_theme, luminance, contrast, suggest_foreground_for_bg, rgb_to_hex, test_calculate_dominant_color_from_buffer, clear_cache, clear_theme_cache)
- [x] 8.2 Verify build: `just nix-build`

## 9. Remove Dead FeedCache and ClusteringStore Delegation Methods

- [x] 9.1 Remove dead delegation methods from `src/storage/feed_cache.cr`: `get_result`, `get_fetched_time_result`, `all_clusters`, `recent_clustering_items`, `get_item_id`, `get_cluster_info_batch`, `cluster_representative?`, `other_item_ids`, `find_by_keywords`, `save_theme`
- [x] 9.2 Remove dead methods from `src/storage/clustering_store.cr`: `other_item_ids`, `find_by_keywords`, `escape_like_pattern`, `get_cluster_size`, `cluster_representative?`, `get_item_id`, `get_cluster_info_batch`, `recent_clustering_items`, `all_clusters` (deferred — these are called only by dead FeedCache methods)
- [x] 9.3 Verify build: `just nix-build`

## 10. Remove Dead Repository Methods

- [x] 10.1 Remove dead methods from `src/repositories/feed_repository.cr`: `find_all_urls`, `find_all_feeds_with_items`, `find_by_url`, `find_by_pattern`, `find_with_items_slice`, `read_feed_row`, `read_feed_entity` (kept `find_all` — used by admin_controller)
- [x] 10.2 Remove dead methods from `src/repositories/story_repository.cr`: `find_all`, `find_by_id`, `find_by_feed`, `save`, `deduplicate`, `build_story`, `find_feed_by_url`
- [x] 10.3 Remove dead methods from `src/repositories/cluster_repository.cr`: `find_items`, `assign_cluster`
- [x] 10.4 Verify build: `just nix-build`

## 11. Remove Dead Service Methods

- [x] 11.1 Remove dead methods from `src/services/story_service.cr`: `get_clusters`, `get_cluster_items`, `ClustersResult` struct, `ClusterItemsResult` struct
- [x] 11.2 Remove `recluster_all` from `src/services/clustering_service.cr` (kept `recluster_with_lsh` — used by app_bootstrap and admin_controller)
- [x] 11.3 Remove dead methods from `src/services/clustering_engine.cr`: `jaccard_similarity`, `find_similar_for_item`
- [x] 11.4 Remove dead method from `src/storage/cleanup_store.cr`: `cleanup_orphaned_lsh_bands` (public wrapper; private version kept)
- [x] 11.5 Verify build: `just nix-build`

## 12. Remove Dead Config and Error Types

- [x] 12.1 Skip `ClusteringConfig#enabled?` — kept because `_enabled` is a YAML deserialized field
- [x] 12.2 Remove `ConfigState` record from `src/config/structures.cr`
- [x] 12.3 Remove `valid_subreddit_config?` from `src/config/validator.cr`
- [x] 12.4 Remove unused `Feed` struct fields (`subreddit`, `sort`, `over18`) from `src/config/structures.cr`
- [x] 12.5 Remove dead error type aliases (`FeedDataResult`, `TimeResult`, `FetchResult`, `SoftwareFetchResult`, `RedditFetchResult`) from `src/errors.cr`
- [x] 12.6 Verify build: `just nix-build`

## 13. Remove Unused Shard Dependency

- [x] 13.1 Remove `crimage` from `shard.yml`
- [x] 13.2 Run `nix develop . --command shards prune` to update shard.lock (no changes needed — crimage already absent from lock)

## 14. Final Verification

- [x] 14.1 Run `just nix-build` — must succeed
- [x] 14.2 Run `nix develop . --command crystal spec` — all 177 tests pass
- [x] 14.3 Run `nix develop . --command crystal tool unreachable src/quickheadlines.cr` — confirmed removed items are gone
- [x] 14.4 Run `nix develop . --command crystal tool format --check src/` — formatted (4 files auto-formatted)

## Additional Cleanup (discovered during implementation)

- [x] Fix `spec/spec_helper.cr` — remove `require "../src/parser"` for deleted file
- [x] Fix `spec/serializer_verification_spec.cr` — remove `FeedDTO` test and require
- [x] Delete `spec/color_extractor_selection_spec.cr` — tests removed `correct_theme_json`
- [x] Delete `spec/color_extractor_crimage_spec.cr` — tests removed `correct_theme_json`
- [x] Delete `spec/color_extractor_helpers_spec.cr` — tests removed `rgb_to_hex`
- [x] Fix `spec/api_spec.cr` — remove `VersionResponse` and `ApiErrorResponse` tests
- [x] Fix `spec/repository_spec.cr` — remove tests for `find_by_url`, `save`, `find_by_pattern`, `delete_by_url`, `deduplicate`
- [x] Fix `src/controllers/api_base_controller.cr` — remove unused `require "../services/feed_service"`
