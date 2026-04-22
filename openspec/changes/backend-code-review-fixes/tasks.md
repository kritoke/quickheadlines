## 1. Security: Admin Auth Default-Deny

- [ ] 1.1 Change `api_base_controller.cr` `check_admin_auth`: `return false if secret.nil? || secret.empty?` (flip default from allow to deny)
- [ ] 1.2 Require auth on `AdminController#status` — add `check_admin_auth` call before returning stats
- [ ] 1.3 Verify all admin endpoints return 401 without ADMIN_SECRET set
- [ ] 1.4 Verify admin endpoints return 401 with wrong token
- [ ] 1.5 Verify admin endpoints return 202/200 with correct token

## 2. Security: Image Proxy Allowlist

- [ ] 2.1 Add `ALLOWED_PROXY_DOMAINS` constant in `constants.cr` with initial domain set
- [ ] 2.2 Replace `validate_proxy_url` in `proxy_controller.cr` with allowlist check (scheme=https, host in allowlist, no credentials, no port)
- [ ] 2.3 Replace error message from 403 "Invalid or disallowed proxy URL" to 403 "Disallowed proxy domain"
- [ ] 2.4 Add streaming response with early size check for `proxy_image` (>MAX_PROXY_IMAGE_BYTES → 413)
- [ ] 2.5 Verify proxy to allowlisted domain works
- [ ] 2.6 Verify proxy to non-allowlisted domain returns 403
- [ ] 2.7 Verify large response (>5MB) returns 413

## 3. Security: Path Traversal + Body Limits

- [ ] 3.1 Add `MAX_REQUEST_BODY_SIZE = 1_048_576` constant in `constants.cr`
- [ ] 3.2 Add `read_body_safe(io : IO, max_size : Int32)` helper in `utils.cr`
- [ ] 3.3 Update `FeedsController#save_header_color` to use `read_body_safe`
- [ ] 3.4 Update `AdminController#admin` to use `read_body_safe`
- [ ] 3.5 Add hash format validation (64-char hex) and extension validation (known types only) in `favicon_file`
- [ ] 3.6 Add path containment check using `File.expand_path` and prefix comparison in `favicon_file`
- [ ] 3.7 Verify body >1MB returns 413 on `POST /api/header_color`
- [ ] 3.8 Verify path traversal attempt returns 400 on favicon endpoint
- [ ] 3.9 Verify non-existent favicon returns 404

## 4. Security: CSP Hardening

- [ ] 4.1 Replace `unsafe-inline` in CSP with nonce-based approach for script/style tags in `static_controller.cr`
- [ ] 4.2 Verify application loads correctly with hardened CSP (no console errors)
- [ ] 4.3 Fallback: if nonce approach proves too complex for Svelte build pipeline, retain `unsafe-inline` with documented justification

## 5. State: Atomic Clustering State

- [ ] 5.1 Add `@@clustering_mutex : Mutex` to `StateStore` in `models.cr`
- [ ] 5.2 Add `@@clustering_start_time : Time?` to `StateStore`
- [ ] 5.3 Add `start_clustering_if_idle : Bool` atomic method to `StateStore`
- [ ] 5.4 Update `ClusteringService#recluster_all` to use `start_clustering_if_idle`
- [ ] 5.5 Update `ClusteringService#recluster_with_lsh` to use `start_clustering_if_idle`
- [ ] 5.6 Update `AppBootstrap#run_initial_clustering` to use `start_clustering_if_idle`
- [ ] 5.7 Add watchdog check in `start_clustering_scheduler`: if clustering_start_time > 4 hours ago, log warning and reset clustering=false
- [ ] 5.8 Verify concurrent clustering requests don't both start (race condition test)

## 6. Data: Canonical Domain Model

- [ ] 6.1 Create `src/domain/` directory
- [ ] 6.2 Create `src/domain/items.cr` with `QuickHeadlines::Domain::FeedItem` and `QuickHeadlines::Domain::TimelineEntry`
- [ ] 6.3 Add `require "./domain/items"` to `application.cr`
- [ ] 6.4 Update `StoryRepository#find_timeline_items` return type to `Array(TimelineEntry)`
- [ ] 6.5 Update `StoryRepository#find_all` return type to use `Entities::Story` (already correct — no change needed)
- [ ] 6.6 Update `ClusterRepository#find_items` and `ClusterRepository#find_all` to use `TimelineEntry`
- [ ] 6.7 Update `DatabaseService#get_timeline_items` to use `TimelineEntry` or remove (dead code — see task 10.3)
- [ ] 6.8 Update `clustering_repo.cr` `get_cluster_items_full`, `get_recent_items_for_clustering` return types
- [ ] 6.9 Verify code compiles with `nix develop . --command crystal build --release src/quickheadlines.cr -o bin/quickheadlines`

## 7. Data: Dead Code Removal

- [ ] 7.1 Remove `DatabaseService#get_timeline_items` (never called from controllers)
- [ ] 7.2 Remove `FeedState` module and all subtypes from `feed_state.cr`
- [ ] 7.3 Remove `StoryGroup` record from `models.cr`
- [ ] 7.4 Remove `ClusteredTimelineItem` record and `to_clustered` helper from `models.cr`
- [ ] 7.5 Remove `StateStore#feeds_for_tab_impl` from `models.cr`
- [ ] 7.6 Remove `StateStore#all_timeline_items_impl` from `models.cr`
- [ ] 7.7 Verify code compiles after removals
- [ ] 7.8 Verify no existing tests break

## 8. Data: Namespace Hierarchy

- [ ] 8.1 Move `Constants` → `QuickHeadlines::Constants` in `constants.cr`
- [ ] 8.2 Update all references to `Constants` across all `.cr` files
- [ ] 8.3 Move `StateStore` → `QuickHeadlines::State::StateStore` in `models.cr`
- [ ] 8.4 Update all references to `StateStore` across all `.cr` files
- [ ] 8.5 Update all mixin module includes from `include ClusteringRepository` to `include QuickHeadlines::Storage::ClusteringRepository`
- [ ] 8.6 Update all `require` statements for affected modules
- [ ] 8.7 Verify full project compiles with `just nix-build`

## 9. Data: Dual Migration Elimination

- [ ] 9.1 Remove `add_column_if_missing` calls from `DatabaseService#create_schema`
- [ ] 9.2 Remove `migrate_lsh_bands_if_needed` call from `DatabaseService#create_schema`
- [ ] 9.3 Verify all required columns are covered by versioned migrations in `database.cr`
- [ ] 9.4 Create migration for any missing columns (if any were only in the ad-hoc system)
- [ ] 9.5 Verify fresh DB init works correctly with existing migrations

## 10. Perf: N+1 Query Elimination

- [ ] 10.1 Add `FeedRepository#find_all_with_items : Hash(String, FeedData)` using single JOIN query
- [ ] 10.2 Update `FeedCache#entries` to use `find_all_with_items` instead of N+1 pattern
- [ ] 10.3 Remove `entries` mutex around query (only hold mutex for final hash assignment)
- [ ] 10.4 Verify `entries` returns correct `Hash(String, FeedData)`
- [ ] 10.5 Benchmark: measure query count and latency before/after

## 11. Perf: Mutex Read Optimization

- [ ] 11.1 Remove `@mutex.synchronize` from `get_item_signature` in `clustering_repo.cr`
- [ ] 11.2 Remove `@mutex.synchronize` from `get_item_title`
- [ ] 11.3 Remove `@mutex.synchronize` from `get_item_feed_id`
- [ ] 11.4 Remove `@mutex.synchronize` from `get_feed_id`
- [ ] 11.5 Remove `@mutex.synchronize` from `get_cluster_size`
- [ ] 11.6 Remove `@mutex.synchronize` from `cluster_representative?`
- [ ] 11.7 Remove `@mutex.synchronize` from `get_item_id`
- [ ] 11.8 Remove `@mutex.synchronize` from `get_item_ids_batch`
- [ ] 11.9 Remove `@mutex.synchronize` from `get_cluster_info_batch`
- [ ] 11.10 Remove `@mutex.synchronize` from `get_cluster_items`
- [ ] 11.11 Remove `@mutex.synchronize` from `find_lsh_candidates`
- [ ] 11.12 Remove `@mutex.synchronize` from `all_clusters`
- [ ] 11.13 Remove `@mutex.synchronize` from `get_cluster_items_full`
- [ ] 11.14 Remove `@mutex.synchronize` from `find_all_items_excluding`
- [ ] 11.15 Remove `@mutex.synchronize` from `find_by_keywords`
- [ ] 11.16 Keep mutex on write methods: `store_item_signature`, `store_lsh_bands`, `assign_cluster`, `assign_clusters_bulk`, `clear_clustering_metadata`
- [ ] 11.17 Run concurrent test to verify no race conditions on reads

## 12. Perf: Redundant Sort Removal

- [ ] 12.1 Remove O(n log n) sort from `Api.feed_to_response` in `api.cr`
- [ ] 12.2 Verify items are already sorted by pub_date DESC in `feed_repository.cr` insert path
- [ ] 12.3 Verify timeline API response is correctly ordered

## 13. Error: Typed Exception Handling

- [ ] 13.1 Audit all bare `rescue` blocks across all `.cr` files — create a list
- [ ] 13.2 For each bare rescue: determine if expected failure (DB not found, parse error) or unexpected
- [ ] 13.3 Replace expected-failure rescues with typed `rescue ex : DB::Error` or `rescue ex : JSON::ParseException`
- [ ] 13.4 Replace unexpected-failure rescues with `rescue ex : Exception` that logs and re-raises
- [ ] 13.5 Ensure all `rescue` blocks in repositories return `Result.failure` with appropriate `RepositoryError`
- [ ] 13.6 Verify all `rescue` blocks log with context

## 14. Error: Structured Logging

- [ ] 14.1 Initialize `Log` with backend at application startup in `quickheadlines.cr`
- [ ] 14.2 Replace `STDERR.puts` in `database.cr` with `Log.for("quickheadlines.storage")`
- [ ] 14.3 Replace `STDERR.puts` in `feed_cache.cr` with `Log.for("quickheadlines.storage")`
- [ ] 14.4 Replace `STDERR.puts` in `clustering_repo.cr` with `Log.for("quickheadlines.storage")`
- [ ] 14.5 Replace `STDERR.puts` in `cleanup.cr` with `Log.for("quickheadlines.storage")`
- [ ] 14.6 Replace `STDERR.puts` in `header_colors.cr` with `Log.for("quickheadlines.storage")`
- [ ] 14.7 Replace `STDERR.puts` in `clustering_service.cr` with `Log.for("quickheadlines.clustering")`
- [ ] 14.8 Replace `STDERR.puts` in `clustering_engine.cr` with `Log.for("quickheadlines.clustering")`
- [ ] 14.9 Replace `STDERR.puts` in `feed_repository.cr` with `Log.for("quickheadlines.feed")`
- [ ] 14.10 Replace `STDERR.puts` in `proxy_controller.cr` with `Log.for("quickheadlines.http")`
- [ ] 14.11 Replace `STDERR.puts` in `api_base_controller.cr` with `Log.for("quickheadlines.http")`
- [ ] 14.12 Replace `STDERR.puts` in `app_bootstrap.cr` with `Log.for("quickheadlines.app")`
- [ ] 14.13 Replace `STDERR.puts` in `socket_manager.cr` with `Log.for("quickheadlines.websocket")`
- [ ] 14.14 Replace `STDERR.puts` in `event_broadcaster.cr` with `Log.for("quickheadlines.websocket")`
- [ ] 14.15 Replace `STDERR.puts` in `static_controller.cr` with `Log.for("quickheadlines.http")`
- [ ] 14.16 Ensure all exception logging uses `exception: ex` parameter
- [ ] 14.17 Verify no `STDERR.puts` remains in application code (grep check)

## 15. Arch: FeedCache God Object Split

- [ ] 15.1 Create `src/storage/clustering_store.cr` with `QuickHeadlines::Storage::ClusteringStore` class
- [ ] 15.2 Move all methods from `ClusteringRepository` mixin into `ClusteringStore`
- [ ] 15.3 Create `src/storage/header_color_store.cr` with `QuickHeadlines::Storage::HeaderColorStore` class
- [ ] 15.4 Move all methods from `HeaderColorsRepository` mixin into `HeaderColorStore`
- [ ] 15.5 Create `src/storage/cleanup_store.cr` with `QuickHeadlines::Storage::CleanupStore` class
- [ ] 15.6 Move all methods from `CleanupRepository` mixin into `CleanupStore`
- [ ] 15.7 Convert `ClusteringRepository` mixin to `QuickHeadlines::Storage::ClusteringRepository` module
- [ ] 15.8 Convert `HeaderColorsRepository` mixin to `QuickHeadlines::Storage::HeaderColorsRepository` module
- [ ] 15.9 Convert `CleanupRepository` mixin to `QuickHeadlines::Storage::CleanupRepository` module
- [ ] 15.10 Refactor `FeedCache` to compose `ClusteringStore`, `HeaderColorStore`, `CleanupStore`
- [ ] 15.11 Update `FeedCache.instance` to create properly initialized instance
- [ ] 15.12 Verify `FeedCache` method signatures unchanged
- [ ] 15.13 Verify full project compiles

## 16. Arch: Controller Split

- [ ] 16.1 Create `src/controllers/config_controller.cr` with `ConfigController`
- [ ] 16.2 Create `src/controllers/tabs_controller.cr` with `TabsController`
- [ ] 16.3 Create `src/controllers/header_color_controller.cr` with `HeaderColorController`
- [ ] 16.4 Create `src/controllers/feed_pagination_controller.cr` with `FeedPaginationController`
- [ ] 16.5 Remove moved endpoints from `FeedsController`
- [ ] 16.6 Update `application.cr` to require new controllers
- [ ] 16.7 Verify all endpoint paths unchanged
- [ ] 16.8 Verify full project compiles

## 17. Data: Tuple Return Type Cleanup

- [ ] 17.1 Define `TimelineRow` named struct in `models.cr` (14 fields matching `get_timeline_items` return)
- [ ] 17.2 Update `DatabaseService#get_timeline_items` return type to `Array(TimelineRow)` (or remove if dead code)
- [ ] 17.3 Define `ClusteringItemRow` named struct for `get_recent_items_for_clustering` return
- [ ] 17.4 Define `ClusterInfoRow` named struct for `get_cluster_items_full` return
- [ ] 17.5 Verify all tuple return types replaced with named structs
- [ ] 17.6 Verify full project compiles

## 18. Verification: Build + Tests

- [ ] 18.1 Run `just nix-build` — must succeed
- [ ] 18.2 Run `nix develop . --command crystal spec` — all existing tests pass
- [ ] 18.3 Verify application starts and serves homepage
- [ ] 18.4 Manual smoke test: `GET /api/feeds` returns 200
- [ ] 18.5 Manual smoke test: `GET /api/timeline` returns 200
- [ ] 18.6 Manual smoke test: admin endpoints return 401 without auth
