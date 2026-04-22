## Context

The timeline API endpoint (`/api/timeline`) fetches items from the SQLite database with clustering logic to show only representative items per cluster. The current implementation has significant performance issues:

**Current Query Problems:**
1. **Correlated Subqueries**: Two expensive subqueries run per row:
   - `SELECT MIN(id) FROM items WHERE cluster_id = i.cluster_id` - finds cluster representative
   - `SELECT COUNT(*) FROM items WHERE cluster_id = i.cluster_id` - counts cluster size

2. **Complex WHERE Clause**: Contains subqueries that prevent index usage:
   ```sql
   AND (i.cluster_id IS NULL OR i.id = (SELECT MIN(id) FROM items WHERE cluster_id = i.cluster_id))
   ```

3. **Missing Composite Indexes**: Current indexes are single-column only:
   - `idx_items_pub_date` - only on pub_date
   - `idx_items_cluster` - only on cluster_id
   - No composite index for the timeline query's ordering/filtering pattern

**Stakeholders:**
- End users viewing the timeline page
- Application performance (response time SLAs)

## Goals / Non-Goals

**Goals:**
- Reduce timeline query time from seconds to milliseconds for typical workloads
- Add appropriate composite indexes without excessive storage overhead
- Maintain exact same query results (no behavior changes)

**Non-Goals:**
- Change clustering algorithm or behavior
- Migrate to a different database
- Add query caching layer (future work)
- Optimize other API endpoints (focus on timeline)

## Decisions

### Decision 1: Add Composite Indexes

**Choice**: Add three composite indexes:
1. `idx_items_timeline`: `(pub_date DESC, id DESC, cluster_id)` - covers timeline query ordering and filtering
2. `idx_items_cluster_rep`: `(cluster_id, id)` - optimizes cluster representative lookups
3. `idx_items_feed_timeline`: `(feed_id, pub_date DESC, id DESC)` - optimizes feed-specific timeline queries

**Rationale**: SQLite can only use one index per table scan. Composite indexes allow the query planner to use a single index for multiple WHERE clause components and ORDER BY.

**Alternatives Considered:**
- Single broad index on all columns: Too wide, wasteful storage
- Partial indexes: Not supported well in SQLite for this use case
- Covering index: Would require including all selected columns, making index too large

### Decision 2: Optimize Query Structure

**Choice**: Rewrite query to use CTE (Common Table Expression) to pre-compute cluster representatives and sizes once, then join.

**Rationale**: Current query runs 2 subqueries per row. With 500 items, that's 1000 subquery executions. A CTE computes these once.

**Alternative Approaches Considered:**
- Materialized view: Would require trigger maintenance, complex for this use case
- Denormalization: Add `is_representative` column to items table - adds write complexity
- Application-side filtering: Still requires fetching all rows, network overhead

### Decision 3: Index Creation Method

**Choice**: Add index creation in `FeedCache#ensure_indexes` method.

**Rationale**: Already has pattern for creating indexes on startup. Simpler than migration system.

**Alternative**: Migration script - overkill for this small change.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Index creation time on large DB | Initial startup may slow | Index creation is incremental, typically fast for SQLite |
| Index storage overhead | Additional disk space | ~10-20% increase, acceptable for the dataset size |
| Query behavior change | Possible edge case differences | Extensive testing with existing data |
| Query plan changes | Unexpected performance regression | Monitor query times after deployment |

## Migration Plan

1. **Deploy indexes**: Add index creation to `ensure_indexes`, runs on every startup (idempotent)
2. **Deploy query change**: Update `story_repository.cr` with optimized query
3. **Verify**: Run timeline API, verify response times improved
4. **Monitor**: Watch for any query time regressions

**Rollback**: Revert code changes; indexes remain but won't hurt performance.

## Open Questions

1. **Should we add `cluster_id` + `is_representative` denormalization?** - Would eliminate subqueries entirely but adds write complexity. Worth considering if performance is still insufficient after indexes.

2. **Timeline query uses `COALESCE(i.pub_date, '1970-01-01')` for ordering** - Could we use a default date in the distant past rather than epoch 0? Minor optimization.
