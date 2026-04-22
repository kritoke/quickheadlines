## 1. Security Fixes

- [ ] 1.1 Add `check_admin_auth(request)` guard to `HeaderColorController#save_header_color` in `src/controllers/header_color_controller.cr`
- [ ] 1.2 Add rate limiting to `FeedPaginationController` using the same pattern as `ProxyController` (30 req/min per IP)

## 2. Clustering State Race Condition

- [ ] 2.1 In `src/models.cr`, update `StateStore.clustering=` to use `@@clustering_mutex` instead of `@@mutex`
- [ ] 2.2 Update `StateStore.start_clustering_if_idle` to use `@@clustering_mutex` only (remove separate locking)
- [ ] 2.3 Ensure all other StateStore methods (`get`, `update`, etc.) continue using `@@mutex` for general state
- [ ] 2.4 Verify no other code path sets `clustering` without going through `@@clustering_mutex`

## 3. WebSocket IP Count Double-Decrement

- [ ] 3.1 In `src/websocket/socket_manager.cr`, modify `cleanup_dead_connections` to NOT call `decrement_ip_count` directly
- [ ] 3.2 Change `cleanup_dead_connections` to only close the outgoing channel (same pattern as `unregister` method)
- [ ] 3.3 Verify writer_fiber's `Channel::ClosedError` handler correctly calls `unregister_connection` for all close paths
- [ ] 3.4 Ensure `decrement_ip_count` is only called from `unregister_connection`

## 4. Timeline Count Pagination Fix

- [ ] 4.1 In `src/repositories/story_repository.cr`, update `count_timeline_items` to include the `cluster_info` CTE
- [ ] 4.2 Apply the same `i.id = ci.representative_id` filter in `count_timeline_items` as used in `find_timeline_items`
- [ ] 4.3 Verify the `has_more` calculation in `StoryService.get_timeline` now correctly reflects visible items

## 5. EventBroadcaster Double-Count Fix

- [ ] 5.1 In `src/websocket/event_broadcaster.cr`, remove `PROCESSED_EVENTS.add(1)` from `notify_feed_update` (line 30)
- [ ] 5.2 Keep the increment only in the broadcast loop (line 16) where actual socket delivery occurs
- [ ] 5.3 Verify `stats` method now returns accurate counts

## 6. Admin Clear-Cache Transaction Safety

- [ ] 6.1 In `src/controllers/admin_controller.cr`, wrap `clear-cache` actions in BEGIN/COMMIT/ROLLBACK transaction
- [ ] 6.2 Wrap `cleanup-orphaned` actions in BEGIN/COMMIT/ROLLBACK transaction
- [ ] 6.3 Add error logging for transaction failures

## 7. Time Parsing Error Handling

- [ ] 7.1 In `src/repositories/story_repository.cr`, wrap `Time.parse` at line 196 with begin/rescue returning `nil` for unparseable dates
- [ ] 7.2 In `src/repositories/cluster_repository.cr`, wrap `Time.parse` at line 61 with begin/rescue returning `nil`
- [ ] 7.3 In `src/repositories/feed_repository.cr`, wrap `Time.parse` in `insert_items` and `upsert_feed` methods
- [ ] 7.4 In `src/storage/clustering_store.cr`, wrap `Time.parse` in `get_recent_items_for_clustering` and `get_cluster_items_full`

## 8. Frontend Console.log Cleanup

- [ ] 8.1 Remove all `console.log` debug statements from `frontend/src/lib/api.ts`
- [ ] 8.2 Remove all `console.log` debug statements from `frontend/src/lib/stores/feedStore.svelte.ts`

## 9. Verification

- [ ] 9.1 Run `just nix-build` to verify compilation succeeds
- [ ] 9.2 Run Crystal tests: `nix develop . --command crystal spec`
- [ ] 9.3 Run frontend tests: `cd frontend && npm run test`