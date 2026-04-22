## 1. WebSocket IP Count Leak Fix

- [x] 1.1 Fix cleanup_dead_connections to call unregister_connection instead of manual removal (socket_manager.cr:238-254)

## 2. Clustering State Management Fixes

- [x] 2.1 Remove @@clustering_mutex and use @@mutex consistently for clustering flag (models.cr:116-127)
- [x] 2.2 Update start_clustering_if_idle to return snapshot via StateStore.update pattern (models.cr:129-138)
- [x] 2.3 Replace CLUSTERING_JOBS atomic counter with Channel-based completion tracking (refresh_loop.cr:125-151)
- [x] 2.4 Remove redundant start_janitor method and its spawn loop (app_bootstrap.cr:65-77)

## 3. Feed Item Deduplication Fix

- [x] 3.1 Remove title-based deduplication in insert_items (feed_repository.cr:376-400)
- [x] 3.2 Simplify to use INSERT OR IGNORE with existing unique constraint only
- [x] 3.3 Update batch_update to handle existing items by link correctly

## 4. Database Connection Lifecycle Fix

- [x] 4.1 Wrap FeedCache DB initialization in proper error handling (feed_cache.cr:46-51)
- [x] 4.2 Ensure connection is closed if create_schema raises

## 5. WebSocket Security Improvements

- [x] 5.1 Add Origin header validation to WebSocket handler (quickheadlines.cr:40-59)
- [x] 5.2 Reject connections with mismatched Origin

## 6. Rate Limiter Thread Safety Fix

- [x] 6.1 Protect @@instances hash with mutex during get_or_create (rate_limiter.cr:40-48)
- [x] 6.2 Use @@cleanup_lock for instance creation synchronization

## 7. Consistent UTC Timestamps

- [x] 7.1 Replace Time.local with Time.utc in StateStore initialization (models.cr:71)
- [x] 7.2 Replace Time.local with Time.utc in refresh_all (refresh_loop.cr:103)
- [x] 7.3 Replace Time.local with Time.utc in feed_fetcher load_from_cache (feed_fetcher.cr:208)

## 8. Frontend WebSocket Listener Cleanup

- [x] 8.1 Add removeEventListener call in +page.svelte $effect cleanup (frontend/src/routes/+page.svelte:92-94)

## 9. Build Verification

- [x] 9.1 Run just nix-build to verify compilation
- [x] 9.2 Run crystal spec for backend tests
- [x] 9.3 Run frontend npm test for smoke test
