## 1. Add Composite Database Indexes

- [ ] 1.1 Add `idx_items_timeline` index on `(pub_date DESC, id DESC, cluster_id)` in `FeedCache#ensure_indexes`
- [ ] 1.2 Add `idx_items_cluster_rep` index on `(cluster_id, id)` in `FeedCache#ensure_indexes`
- [ ] 1.3 Add `idx_items_feed_timeline` index on `(feed_id, pub_date DESC, id DESC)` in `FeedCache#ensure_indexes`
- [ ] 1.4 Verify existing `idx_lsh_band_search` index is present

## 2. Optimize Timeline Query Structure

- [ ] 2.1 Rewrite `find_timeline_items` in `StoryRepository` to use CTE for cluster representatives
- [ ] 2.2 Pre-compute cluster sizes in CTE instead of per-row subquery
- [ ] 2.3 Ensure query still filters to only cluster representatives in WHERE clause

## 3. Verify and Test

- [ ] 3.1 Run `just nix-build` to ensure compilation succeeds
- [ ] 3.2 Start server and verify timeline API responds correctly
- [ ] 3.3 Check query performance with EXPLAIN (optional debug)
- [ ] 3.4 Run existing tests to ensure no regressions

## 4. Final Verification

- [ ] 4.1 Verify timeline returns items in correct order (pub_date DESC, id DESC)
- [ ] 4.2 Verify cluster representatives are correctly identified
- [ ] 4.3 Verify cluster sizes are accurate for representative items
- [ ] 4.4 Archive change after all tasks complete
