## Why

The timeline API endpoint (`/api/timeline`) suffers from poor performance due to complex SQL queries with multiple correlated subqueries and missing composite indexes. This causes slow page loads, especially on the timeline page with many items (100s-1000s), impacting user experience. The database queries perform full scans for clustering representative lookups and cluster size calculations.

## What Changes

- Add composite database indexes for timeline query optimization:
  - `(pub_date DESC, id DESC, cluster_id)` for timeline ordering and filtering
  - `(cluster_id, id)` for representative item lookups
  - `(feed_id, pub_date DESC, id DESC)` for feed-specific queries
- Optimize timeline SQL query to reduce/eliminate correlated subqueries:
  - Replace per-row subqueries with JOIN-based approach
  - Pre-compute cluster representative IDs and sizes in temporary tables or CTEs
- Add index for LSH band searches used in clustering

## Capabilities

### New Capabilities
- `database-index-optimization`: Add composite indexes for timeline and clustering queries to improve query performance

### Modified Capabilities
- None - this is a pure performance optimization that doesn't change behavior

## Impact

- **Database Layer**: New composite indexes, optimized query structure
- **API**: `/api/timeline` endpoint performance improvement
- **Clustering**: Faster cluster representative lookups
