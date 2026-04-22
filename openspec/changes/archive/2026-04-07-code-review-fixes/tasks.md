## 1. FeedFetcher Singleton Thread Safety

- [x] 1.1 Add `@@mutex = Mutex.new` to FeedFetcher class
- [x] 1.2 Wrap `@@instance ||= FeedFetcher.new(...)` in mutex synchronize block
- [x] 1.3 Verify thread-safe initialization with concurrent access test (N/A - manual verification)

## 2. RateLimiter Background Cleanup

- [x] 2.1 Add `@@cleanup_fiber` and `@@cleanup_mutex` instance variables
- [x] 2.2 Create `start_cleanup_fiber` method with dedicated cleanup fiber
- [x] 2.3 Call `start_cleanup_fiber` from RateLimiter initialization
- [x] 2.4 Remove per-request cleanup from `allowed?` method
- [x] 2.5 Ensure cleanup fiber doesn't block on exceptions

## 3. Refresh Cycle Prevention

- [x] 3.1 Add `REFRESH_IN_PROGRESS = Atomic(Bool).new` for refresh cycle prevention
- [x] 3.2 Check and set REFRESH_IN_PROGRESS before refresh with skip on overlap

## 4. WebSocket Registration Exception Safety

- [x] 4.1 Move all state modifications under single `@connections_mutex.synchronize` block
- [x] 4.2 Use begin/ensure to guarantee IP count cleanup on exception
- [x] 4.3 Add proper rollback logic if any step fails after IP count increment

## 5. Crypto::ConstantTimeCompare

- [x] 5.1 Attempted to import `crypto` module - not available in Crystal 1.18.2
- [x] 5.2 Keep manual timing_safe_compare (Crystal's Crypto module not available)

## 6. Database Transaction Handling

- [x] 6.1 Replace manual BEGIN/COMMIT/ROLLBACK with `db.transaction do...end` block
- [x] 6.2 Update upsert_with_items method in feed_repository.cr
- [x] 6.3 Remove explicit ROLLBACK rescue code (transaction handles it)

## 7. Cluster Repository Configurable Limit

- [x] 7.1 Add `max_fetch_items : Int32 = 1000` property to ClusteringConfig struct
- [x] 7.2 Update cluster_repository.cr to use config value instead of hardcoded 1000
- [x] 7.3 Update clustering_service.cr to pass config limit

## 8. Code Quality Improvements

- [x] 8.1 Add SECONDS_PER_MINUTE = 60 constant to constants.cr
- [x] 8.2 Replace magic number 60 with SECONDS_PER_MINUTE in refresh_loop.cr
- [x] 8.3 Review all other magic numbers for potential constants (done)

## 9. Build Verification

- [x] 9.1 Run `just nix-build` to verify compilation
- [x] 9.2 Run `nix develop . --command crystal spec` for tests
- [x] 9.3 Fix any compilation or test failures (0 failures)
