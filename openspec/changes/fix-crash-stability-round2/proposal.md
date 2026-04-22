## Why

Secondary stability fixes for FreeBSD jail crashes. The initial round addressed clustering timeouts, LSH cleanup, graceful shutdown, and Vug cache clearing. This round addresses the most likely root cause: SQLite SQLITE_BUSY errors from concurrent writes with zero busy_timeout, HTTP::Client file descriptor leaks, and feed fetch concurrency deadlocks.

## What Changes

1. **Add busy_timeout to SQLite connections** - Prevent immediate SQLITE_BUSY failures when concurrent writes occur
2. **Add FreeBSD-specific SQLite PRAGMAs** - Disable mmap and set wal_autocheckpoint for FreeBSD/ZFS stability
3. **Close HTTP::Client connections properly** - Fix FD leaks in proxy_controller and favicon_storage
4. **Add write_timeout to HTTP clients** - Prevent indefinite write blocking
5. **Guard feed fetch channel.receive with timeout** - Prevent deadlock if spawned fibers fail
6. **Set max_pool_size on DB connection** - Prevent unbounded connection pool growth
7. **Add foreign_keys PRAGMA to top-level create_schema** - Fix inconsistent PRAGMA settings
8. **Add timeouts to github_sync HTTP call** - Prevent startup hang
9. **Add async_clustering concurrency guard** - Prevent concurrent clustering execution

## Capabilities

### New Capabilities
- `sqlite-busy-timeout`: Add busy_timeout and FreeBSD-specific PRAGMAs to SQLite connections for stability under concurrent write load
- `http-client-cleanup`: Properly close HTTP::Client connections and add write_timeout to prevent FD leaks and hangs
- `feed-fetch-deadlock-guard`: Add timeout and error recovery to fetch_feeds_concurrently to prevent permanent deadlock

### Modified Capabilities
- `graceful-shutdown`: (existing) No requirement changes

## Impact

**Affected Code:**
- `src/services/database_service.cr` - SQLite PRAGMAs and connection string
- `src/storage/database.cr` - Top-level create_schema PRAGMAs
- `src/controllers/proxy_controller.cr` - HTTP::Client lifecycle
- `src/favicon_storage.cr` - HTTP::Client lifecycle
- `src/utils.cr` - HTTP::Client timeouts
- `src/fetcher/refresh_loop.cr` - Feed fetch deadlock guard, clustering concurrency
- `src/config/github_sync.cr` - HTTP timeouts

**No Breaking Changes** - All changes are internal stability improvements.
