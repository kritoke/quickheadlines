# perf-feed-entries-query

**Owner:** Backend Team  
**Status:** proposed

## Overview

Replace the N+1 query pattern in `FeedCache#entries` with a single efficient JOIN query. Currently executes 2N+1 queries (1 for URLs + N for feed rows + N for items) under a mutex lock.

## Requirements

### REQ-001: Single JOIN Query
`FeedRepository#find_all_with_items` executes one query that:
1. SELECTs all feeds
2. LEFT JOINs items
3. Orders feeds by title, items by pub_date DESC
4. Returns `Hash(String, FeedData)`

### REQ-002: Memory-Efficient Streaming
For databases with very large item counts per feed, the query streams results using `db.query` (not `db.query_all`) to avoid loading the entire result set into memory at once.

### REQ-003: Mutex Not Held During Query
The mutex is released during the query execution. It is only held when writing the final `Hash(String, FeedData)` result.

### REQ-004: Backward-Compatible API
`FeedCache#entries` method signature remains unchanged: `Hash(String, FeedData)`.

## Acceptance Criteria

- [ ] `FeedCache#entries` executes exactly 1 SQL query (verified via query logging)
- [ ] Return type remains `Hash(String, FeedData)`
- [ ] Mutex is not held during I/O
- [ ] Benchmark shows <50% of previous latency for 20+ feeds

## Affected Files

- `src/repositories/feed_repository.cr` — `find_all_with_items`
- `src/storage/feed_cache.cr` — `entries` method
