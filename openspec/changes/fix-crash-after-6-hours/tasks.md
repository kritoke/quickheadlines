## 1. Clustering Timeout Fix

- [x] 1.1 Modify async_clustering in refresh_loop.cr to use Channel.select with timeout
- [x] 1.2 Add 5-minute timeout constant for clustering completion
- [x] 1.3 Add warning log when clustering times out with completion count

## 2. LSH Band Cleanup

- [x] 2.1 Add cleanup_orphaned_lsh_bands method to CleanupStore
- [x] 2.2 Call cleanup_orphaned_lsh_bands in cleanup_old_articles
- [x] 2.3 Call cleanup_orphaned_lsh_bands in check_size_limit aggressive cleanup
- [x] 2.4 Enable foreign keys in DatabaseService.create_schema (PRAGMA foreign_keys = ON)

## 3. Graceful Shutdown

- [x] 3.1 Add at_exit handler in AppBootstrap to call DatabaseService.close
- [x] 3.2 Add shutdown log message before cleanup
- [x] 3.3 Wrap DatabaseService.close in rescue to prevent at_exit from crashing

## 4. Vug Cache Periodic Clearing

- [x] 4.1 Add VugAdapter.clear_cache call in start_cleanup_scheduler loop
- [x] 4.2 Add debug log when cache is cleared

## 5. Build Verification

- [x] 5.1 Run just nix-build to verify compilation
- [x] 5.2 Run crystal spec tests
- [x] 5.3 Verify frontend tests pass
