## Why

Security vulnerabilities and stability issues were identified during code review that require immediate attention:

1. **SQL injection risk** via unsanitized keywords from feed titles in LIKE queries
2. **Nil dereference** in clustering that causes crashes on fresh deployments
3. **Silent transaction failures** that mask data inconsistencies
4. **Monotonic/wall-clock time mixing** that can cause false alerts

These bugs can lead to data corruption, crashes, and potential security breaches. Fixing them now prevents production incidents.

## What Changes

- **SQL Injection Prevention**: Add proper SQL escaping for LIKE pattern keywords in `ClusteringStore#find_by_keywords`
- **Nil Safety**: Add nil checks before using feed_id in `process_feed_item_clustering`
- **Transaction Error Handling**: Make `assign_clusters_bulk` raise on failure instead of silently continuing
- **Time Handling Fix**: Use consistent time sources for refresh duration monitoring
- **Candidate Limit**: Add bounds to LSH candidate search to prevent memory exhaustion
- **Socket Error Handling**: Distinguish between normal connection closures and actual errors
- **Cache Counter Overflow**: Use monotonic time for LRU tiebreaker instead of unbounded counter

## Capabilities

### New Capabilities

- `input-sanitization`: Input sanitization for database queries
  - SQL LIKE patterns properly escape all wildcard characters
  - Keywords derived from external sources are validated before use in queries

- `error-propagation`: Explicit error handling in batch operations
  - Transaction failures in bulk operations are raised to callers
  - Partial failure detection enabled for clustering operations

- `memory-bounds`: Bounded resource consumption
  - LSH candidate sets have configurable size limits
  - Refresh operations have bounded memory allocation

### Modified Capabilities

- (none - these are bug fixes that don't change spec-level behavior)

## Impact

**Affected Code:**
- `src/storage/clustering_store.cr` - SQL injection, transaction handling, candidate bounds
- `src/fetcher/refresh_loop.cr` - nil safety, time handling
- `src/websocket/socket_manager.cr` - error handling
- `src/color_extractor.cr` - cache counter overflow

**Security Impact:**
- Prevents SQL injection attacks via malicious feed titles
- Prevents SSRF via malformed redirect handling

**Stability Impact:**
- Prevents crashes on fresh database deployments
- Prevents silent data inconsistencies in clustering
- Prevents memory exhaustion from unbounded queries
