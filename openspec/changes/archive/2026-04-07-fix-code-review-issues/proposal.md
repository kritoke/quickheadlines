## Why

Code review identified 3 critical bugs, 5 high-severity bugs, and 6 medium/low issues. The most severe is a WebSocket IP count leak in `cleanup_dead_connections` that permanently inflates per-IP connection counters, causing legitimate users to be blocked after the first cleanup cycle. Other critical issues include a dual-mutex race condition on the clustering flag and an incorrect item deduplication strategy that silently drops legitimate articles with common titles.

## What Changes

1. **WebSocket IP count leak fix** (`socket_manager.cr`): `cleanup_dead_connections` now calls `unregister_connection` instead of manual removal, properly decrementing IP counts
2. **Unified clustering mutex** (`models.cr`, `refresh_loop.cr`): Route all `clustering` flag access through `@@mutex` to eliminate the dual-mutex race
3. **Robust clustering job counter** (`refresh_loop.cr`): Use channel-based completion tracking instead of atomic counter that can go stale on fiber crash
4. **DB connection lifecycle** (`feed_cache.cr`): Wrap connection initialization in proper error handling to prevent leaks
5. **Link-based item deduplication** (`feed_repository.cr`): Remove title-based deduplication; rely on existing `UNIQUE(feed_id, link)` constraint
6. **WebSocket origin validation** (`quickheadlines.cr`): Validate `Origin` header to prevent cross-site WebSocket hijacking
7. **Thread-safe rate limiter instantiation** (`rate_limiter.cr`): Protect `@@instances` hash with mutex during creation
8. **Consistent UTC timestamps** (`models.cr`, `refresh_loop.cr`, `feed_fetcher.cr`): Replace mixed `Time.local`/`Time.utc` with `Time.utc` for state timestamps
9. **WebSocket listener cleanup** (`+page.svelte`): Remove listener on component cleanup to prevent accumulation
10. **Remove redundant janitor** (`app_bootstrap.cr`): Eliminate duplicate `start_janitor` that duplicates `start_ws_janitor` work
11. **Consistent Time.utc usage**: Replace remaining `Time.local` calls with `Time.utc`

## Capabilities

### New Capabilities
- `clustering-state-management`: Fixes mutex inconsistency and job counter stability for the clustering subsystem
- `feed-item-deduplication`: Corrects deduplication strategy to use link-based approach instead of title-based
- `database-connection-lifecycle`: Ensures SQLite connections are properly closed on initialization failures
- `websocket-origin-validation`: Adds Origin header checking to prevent cross-site WebSocket connections

### Modified Capabilities
- `websocket-connection`: Add requirement for Origin header validation on server-side WebSocket upgrade
- `rate-limiter-memory-safety`: Clarify that instance creation must be thread-safe, not just cleanup

## Impact

- **Backend**: `src/websocket/socket_manager.cr`, `src/models.cr`, `src/fetcher/refresh_loop.cr`, `src/storage/feed_cache.cr`, `src/repositories/feed_repository.cr`, `src/rate_limiter.cr`, `src/services/app_bootstrap.cr`
- **Frontend**: `frontend/src/routes/+page.svelte`
- **No API changes**: All fixes are internal implementation
- **No dependency changes**: Crystal 1.18.2 compatible
