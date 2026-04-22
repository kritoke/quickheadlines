## Why

The application crashes consistently on FreeBSD in a jail after approximately 6 hours of operation. Investigation reveals several resource management issues: (1) async_clustering fiber can hang indefinitely if spawned fibers fail before completion, (2) LSH bands database table grows unbounded as clustered items are never cleaned up, (3) no graceful shutdown handling causes resource leaks, and (4) Vug MemoryCache is never cleared after startup.

## What Changes

1. **Fix async_clustering completion channel hang** - Add timeout-based completion to prevent indefinitely blocked fibers
2. **Add LSH band cleanup to article deletion** - Cascade delete LSH bands when items are removed
3. **Implement graceful shutdown** - Add at_exit handler and signal traps for proper resource cleanup
4. **Add periodic Vug cache clearing** - Clear Vug adapter cache during 6-hour cleanup cycle
5. **Add cleanup_stale_lsh_bands method** - Remove orphaned LSH band entries during cleanup

## Capabilities

### New Capabilities
- `lsh-band-cleanup`: Add explicit cleanup of LSH bands when items are deleted to prevent unbounded table growth
- `graceful-shutdown`: Implement signal handlers and at_exit to properly close database connections and stop background fibers on termination
- `clustering-timeout`: Add timeout mechanism to async_clustering to prevent indefinitely hung fibers

### Modified Capabilities
- `rate-limiter-memory-safety`: (existing) Already has cleanup - verify implementation is being called properly
- `hybrid-clustering`: (existing) No requirement changes, implementation-only fix for LSH band cleanup

## Impact

**Affected Code:**
- `src/fetcher/refresh_loop.cr` - async_clustering timeout fix
- `src/storage/cleanup_store.cr` - Add LSH band cleanup cascade
- `src/services/app_bootstrap.cr` - Add graceful shutdown handlers
- `src/fetcher/vug_adapter.cr` - Add periodic cache clearing
- `src/services/database_service.cr` - Ensure close is called

**Affected Systems:**
- Database (SQLite) - LSH bands table growth
- Background fibers - Potential hangs
- Memory management - Vug cache growth
- Resource cleanup - Database connections not closed

**No Breaking Changes** - All changes are internal stability improvements with no API or behavior changes visible to users.
