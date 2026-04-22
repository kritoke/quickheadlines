## Why

The Crystal codebase contains several code quality issues that pose correctness risks (race condition in RateLimiter), maintenance burdens, and anti-patterns that reduce code maintainability. Addressing these now prevents technical debt from accumulating and ensures the codebase follows idiomatic Crystal 1.18.2 patterns.

## What Changes

- **Fix race condition** in `RateLimiter.allowed?` by adding mutex synchronization around read-check-write operations
- **Replace manual `copy_with`** in `Cluster` entity with idiomatic `record` macro and computed `size` property
- **Remove redundant `not_nil!`** calls in `ApiBaseController.validate_int` after nil guard checks
- **Delete dead files** `github_fetcher.cr` (empty) and `rate_limit_stats_dto.cr` (unused)
- **Fix N+1 query pattern** in `FeedRepository.insert_items` by pre-partitioning new vs existing items

**Note:** `Time.monotonic` deprecation fix was reverted - `Time.monotonic_now` does not exist in Crystal 1.18.2. The deprecated `Time.monotonic` must be kept for compatibility.

**Note:** Athena request body deserialization was not implemented - Athena 0.21 does not support automatic request body deserialization via annotations. Manual JSON parsing remains the pattern.

## Capabilities

### New Capabilities
- `thread-safe-rate-limiter`: Ensure RateLimiter.allowed? is thread-safe under concurrent access

### Modified Capabilities
(None - all changes are implementation-level quality improvements, not requirement changes)

## Impact

**Files Modified:**
- `src/rate_limiter.cr` - Thread safety fix (added mutex)
- `src/entities/cluster.cr` - Idiom adoption (record macro with computed size)
- `src/controllers/api_base_controller.cr` - Minor cleanup (removed redundant not_nil!)
- `src/controllers/feeds_controller.cr` - Minor cleanup (simplified JSON parsing)
- `src/repositories/cluster_repository.cr` - Updated to use new Cluster constructor
- `src/repositories/feed_repository.cr` - Pre-partition items for efficiency

**Files Deleted:**
- `src/github_fetcher.cr` - Empty/dead file
- `src/dtos/rate_limit_stats_dto.cr` - Unused DTO

**No Breaking Changes:** All changes are backward-compatible improvements.
