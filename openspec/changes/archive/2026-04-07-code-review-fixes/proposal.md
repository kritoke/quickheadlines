## Why

A comprehensive code review identified multiple issues ranging from thread safety problems, race conditions, security concerns, and resource management issues. These need to be fixed before they cause production problems.

## What Changes

1. **Thread Safety Fixes**
   - Make `FeedFetcher.instance` singleton initialization thread-safe using mutex
   - Move `RateLimiter` cleanup from per-request to background fiber
   - Fix race condition in `async_clustering` jobs counter logic

2. **Refresh Loop Overlap Prevention**
   - Add lock to prevent concurrent refresh cycles from overlapping
   - Warn and skip if previous refresh still running

3. **WebSocket Connection Safety**
   - Use `begin/ensure` block in `register()` to guarantee IP count cleanup on exception
   - Move all state modifications under single mutex in register flow

4. **Security Improvements**
   - Replace manual timing-safe comparison with `Crypto::ConstantTimeCompare`
   - Add guard for empty `orphaned` array in SQL query construction

5. **Transaction Handling**
   - Replace manual BEGIN/COMMIT/ROLLBACK with `db.transaction { }` block

6. **Cluster Repository Limits**
   - Make hardcoded 1000 cluster limit configurable via config

7. **Code Quality**
   - Extract magic number `60` (seconds per minute) to constant
   - Add `@[ATOMIC]` annotation to clustering jobs counter for clarity

## Capabilities

### New Capabilities
- `thread-safe-singletons`: Thread-safe initialization patterns for singleton services
- `refresh-cycle-prevention`: Prevents overlapping refresh cycles when previous cycle exceeds schedule

### Modified Capabilities
- `rate-limiter-memory-safety`: (existing) - Move cleanup to background fiber
- `websocket-connection`: (existing) - Improve exception safety in registration

## Impact

**Backend (Crystal)**
- `src/fetcher/feed_fetcher.cr` - Singleton thread safety
- `src/rate_limiter.cr` - Background cleanup
- `src/fetcher/refresh_loop.cr` - Refresh cycle locking, atomic operations
- `src/websocket/socket_manager.cr` - Exception safety
- `src/controllers/api_base_controller.cr` - Use Crypto module
- `src/controllers/admin_controller.cr` - Empty array guard
- `src/repositories/feed_repository.cr` - Use db.transaction
- `src/repositories/cluster_repository.cr` - Configurable limit
- `src/constants.cr` - Add SECONDS_PER_MINUTE constant
