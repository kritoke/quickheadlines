## 1. Storage Module Split

- [x] 1.1 Create `src/storage/` directory structure
- [x] 1.2 Extract cache utilities to `src/storage/cache_utils.cr` (get_cache_dir, get_cache_db_path, normalize_feed_url, get_db_size, format_bytes, log_db_size, ensure_cache_dir, get_db)
- [x] 1.3 Extract database schema/health to `src/storage/database.cr` (create_schema, check_db_integrity, check_db_health, repair_database, repopulate_database, init_db, DbHealthStatus, DbRepairResult)
- [x] 1.4 Extract clustering repository to `src/storage/clustering_repo.cr` (find_all_items_excluding through cluster_representative? methods from FeedCache)
- [x] 1.5 Move FeedCache class to `src/storage/feed_cache.cr` with remaining methods
- [x] 1.6 Create thin `src/storage.cr` require file that requires `./storage/*`
- [x] 1.7 Run `just nix-build` to verify storage split compiles
- [x] 1.8 Run `nix develop . --command crystal spec` to verify tests pass

## 2. Fetcher Module Split

- [x] 2.1 Create `src/fetcher/` directory structure
- [x] 2.2 Extract favicon logic to `src/fetcher/favicon.cr` (FaviconHelper, FaviconCache, fetch_favicon_uri, valid_image?)
- [x] 2.3 Extract feed fetching to `src/fetcher/feed_fetcher.cr` (fetch_feed, load_feeds_from_cache)
- [x] 2.4 Extract refresh loop to `src/fetcher/refresh_loop.cr` (refresh_all, async_clustering, compute_cluster_for_item, process_feed_item_clustering, start_refresh_loop)
- [x] 2.5 Create thin `src/fetcher.cr` require file that requires `./fetcher/*`
- [x] 2.6 Run `just nix-build` to verify fetcher split compiles
- [x] 2.7 Run `nix develop . --command crystal spec` to verify tests pass

## 3. API Controller Split

- [ ] 3.1-3.10 Deferred - Athena controller architecture makes splitting complex; would require multiple controller classes

## 4. Final Verification

- [x] 4.1 Run full build `just nix-build`
- [x] 4.2 Run full test suite `nix develop . --command crystal spec`
- [ ] 4.3 Verify server starts and API endpoints work: `./bin/quickheadlines`
- [x] 4.4 Verify all refactored files are under 600 lines

## Summary

**Completed refactoring:**
- `storage.cr` (1647 lines) → 6 focused modules (avg 243 lines each)
- `fetcher.cr` (1058 lines) → 3 focused modules (avg 315 lines each)
- `api_controller.cr` (813 lines) - Deferred due to Athena architecture constraints

**Line counts after split:**
| File | Lines |
|------|-------|
| storage/cache_utils.cr | 115 |
| storage/cleanup.cr | 152 |
| storage/clustering_repo.cr | 295 |
| storage/database.cr | 240 |
| storage/feed_cache.cr | 542 |
| storage/header_colors.cr | 114 |
| fetcher/favicon.cr | 367 |
| fetcher/feed_fetcher.cr | 402 |
| fetcher/refresh_loop.cr | 177 |
