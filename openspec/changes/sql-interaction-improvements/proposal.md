# SQL Interaction Improvements

## Why

The SQL interaction audit identified several correctness bugs and performance issues in the database layer. The most critical are a runtime-crashing nested transaction in the admin cache-clear operation, silent data loss in LSH band storage, and race conditions in the favicon sync service. Additionally, the timeline query's CTE rescans the entire items table on every request, and several N+1 query patterns exist in the clustering pipeline that could be batched.

## What Changes

1. **Fix nested transaction in admin_controller**: Replace manual `BEGIN/COMMIT` with Crystal's `db.transaction { }` block and add transaction wrapping to `clear_clustering_metadata` and `clear_all`.

2. **Re-raise errors in `store_lsh_bands`**: The exception in the rescue block is logged but swallowed, causing silent data loss. Re-raise after logging so callers know the operation failed.

3. **Add mutex to `backfill_header_colors`**: This method performs a DB write without mutex protection while all other DB writes in `FaviconSyncService` are protected. Add `@mutex.synchronize`.

4. **Batch N+1 in `process_clustering`**: Replace per-item `cache.get_item_id` calls with the existing `cache.get_item_ids_batch` method.

5. **Add date filter to timeline CTE**: The `cluster_info` CTE currently scans all clustered items on every query. Add `AND pub_date >= ?` to match the outer query's date range.

6. **Wrap multi-statement writes in transactions**: Add transactions to `delete_by_url` (2 DELETEs), `clear_all_metadata` (2 writes), `clear_all` (3 DELETEs), and `cleanup_old_articles` (3 writes).

7. **Merge redundant feed queries in `find_with_items`**: Currently runs 2 queries on `feeds` table (one for feed data, one for `id`). Include `id` in the first query.

8. **Merge sequential reads in `update_header_colors` and `update_feed`**: Two and three separate SELECTs on the same row. Combine into single queries.

9. **Add `busy_timeout` to utility connections**: `check_db_integrity` and `check_db_health` open connections without `busy_timeout=5000`.

10. **Merge feed URL lookups in `get_item_ids_batch`**: Each unique feed URL triggers a separate query. Batch into a single `SELECT ... WHERE url IN (...)`.

## Capabilities

### Modified Capabilities

- `data-storage`: SQL interaction patterns (transaction handling, error propagation, batch operations) are corrected to prevent data loss and improve consistency.
- `clustering`: N+1 query patterns in the clustering pipeline are replaced with batch operations.

## Impact

- **Correctness**: Fixes a runtime crash in the admin cache-clear endpoint, prevents silent data loss in LSH band storage, resolves a race condition in favicon sync.
- **Performance**: Reduces per-timeline-query scan by scoping the CTE to the relevant date range; reduces clustering query count via batch operations.
- **No API changes**: All fixes are internal to the data layer.
- **No new dependencies**: All changes use existing Crystal stdlib (`DB` module).
