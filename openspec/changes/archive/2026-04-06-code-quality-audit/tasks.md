## 1. Delete Dead Code

- [ ] 1.1 Delete `src/storage/clustering_repo.cr` (ClusteringRepository module — zero imports)
- [ ] 1.2 Delete `src/storage/cleanup.cr` (CleanupRepository module — only in 1 spec)
- [ ] 1.3 Remove legacy `FeedCache` class stub from `src/models.cr` (lines 170-180)
- [ ] 1.4 Update `spec/cleanup_spec.cr` to reference `CleanupStore` instead of `CleanupRepository`
- [ ] 1.5 Verify build compiles and tests pass after deletions

## 2. Extract Shared Helpers

- [ ] 2.1 Create `QuickHeadlines::Repositories::RepositoryBase` abstract class with shared `initialize(db_or_service)` and `@db` accessor in `src/repositories/repository_base.cr`
- [ ] 2.2 Refactor `FeedRepository` to inherit from `RepositoryBase`
- [ ] 2.3 Refactor `StoryRepository` to inherit from `RepositoryBase`
- [ ] 2.4 Refactor `ClusterRepository` to inherit from `RepositoryBase`
- [ ] 2.5 Refactor `HeatMapRepository` to inherit from `RepositoryBase`
- [ ] 2.6 Add `CacheUtils.parse_db_time(str : String?) : Time?` helper and replace 15+ duplicate time parsing calls
- [ ] 2.7 Add `CacheUtils.placeholders(count : Int) : String` helper and replace 6 duplicate placeholder patterns
- [ ] 2.8 Add `Config#all_feed_urls` method and replace 4 duplicate config URL collection patterns
- [ ] 2.9 Extract `StoryRowMapper` to deduplicate the 9-field row reading pattern repeated 3x in `StoryRepository`

## 3. Rename Long Method Names

- [ ] 3.1 Rename 5-word methods: `auto_upgrade_to_auto_corrected` → `upgrade_theme_json`, `theme_aware_extract_from_favicon` → `extract_theme_colors`, `extract_legacy_header_from_theme` → `parse_legacy_theme`, `add_column_if_not_exists` → `ensure_column`, `find_feed_url_by_pattern` → `match_feed_url`
- [ ] 3.2 Rename 4-word getter methods: drop `get_` prefix from `get_item_signature`, `get_item_feed_id`, `get_item_title`, `get_feed_id`, `get_cluster_items`, `get_cluster_size`, `get_feed_theme_colors`, `get_cache_db_path`, `get_fetched_time_result`
- [ ] 3.3 Rename 4-word action methods: `fetch_config_from_github` → `fetch_github_config`, `download_config_from_github` → `download_github_config`, `load_config_with_validation` → `load_validated_config`, `build_error_feed_data` → `build_error_feed`, `build_cached_feed_data` → `build_cached_feed`, `collect_all_feed_configs` → `collect_feed_configs`
- [ ] 3.4 Rename 4-word Result-returning methods: drop `_result` suffix from `find_by_url_result`, `find_by_pattern_result`, `get_feed_with_items_result`, `get_fetched_time_result`
- [ ] 3.5 Rename remaining 4-word methods: `feed_url_invalid_reason` → `invalid_url_reason`, `extract_theme_text_value` → `extract_theme_text`, `build_feed_filter_clause` → `build_feed_filter`, `build_feed_filter_values` → `feed_filter_values`, `find_heat_for_stories` → `story_heat`, `get_feed_with_items` → `feed_with_items`, `update_feed_theme_colors` → `update_theme_colors`, `get_recent_items_for_clustering` → `recent_clustering_items`, `get_cluster_items_full` → `full_cluster_items`, `get_cluster_info_batch` → `batch_cluster_info`, `get_item_ids_batch` → `batch_item_ids`, `repo_entry_to_url` → `repo_entry_url`

## 4. Split Large Files and Methods

- [ ] 4.1 Split `FeedFetcher#fetch` (97 lines) into `attempt_fetch`, `handle_result`, `fetch_favicon` private methods
- [ ] 4.2 Split `FaviconSyncService#sync_favicon_paths` (148 lines) into `scan_feeds`, `sync_existing_favicons`, `backfill_google_favicons`, `backfill_missing_favicons`
- [ ] 4.3 Extract `TimelineQueryBuilder` from `StoryRepository#find_timeline_items` (92 lines)
- [ ] 4.4 Verify no files exceed 400 lines after splits

## 5. Idiomatic Crystal Cleanup

- [ ] 5.1 Replace `begin/rescue/nil` with `try` in `color_extractor.cr` and `feed_fetcher.cr`
- [ ] 5.2 Replace `nil? || == ""` / `nil? || empty?` with `.blank?` or `.presence` in `feed_fetcher.cr` and `api_base_controller.cr`

## 6. Verification

- [ ] 6.1 Run `just nix-build` and verify success
- [ ] 6.2 Run `nix develop . --command crystal spec` and verify all specs pass
- [ ] 6.3 Run `cd frontend && npm run test` and verify frontend tests pass
- [ ] 6.4 Run `nix develop . --command ameba --fix` and resolve any lint issues
