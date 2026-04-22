## 1. Frontend: Fix WebSocket refresh handling in effects.svelte.ts

- [x] 1.1 Add `force` parameter to `loadTimeline()` in `timelineStore.svelte.ts` to bypass loading/refreshing guard
- [x] 1.2 Update `handleFeedUpdate()` in `effects.svelte.ts` to await `loadFeeds()` and `loadTimeline()` before restoring scroll position
- [x] 1.3 Wrap scroll restoration in `queueMicrotask()` to ensure it fires after Svelte DOM updates
- [x] 1.4 Add debounce timer (500ms) to `handleFeedUpdate()` to coalesce rapid `feed_update` events
- [x] 1.5 Remove `refreshInterval` `setInterval` from `createFeedEffects()` — WebSocket is sole refresh trigger
- [x] 1.6 Remove `refreshInterval` `setInterval` from `createTimelineEffects()` — WebSocket is sole refresh trigger
- [x] 1.7 Remove dead `handleClusteringStatus()` function and `clustering_status` WebSocket handler since backend never sends this

## 2. Frontend: Verify build and tests

- [x] 2.1 Run `cd frontend && npm run build` to verify frontend compiles
- [x] 2.2 Run `cd frontend && npm run test` to verify frontend tests pass
- [x] 2.3 Run `just nix-build` to verify full stack builds

## 3. Backend: Fix EventBroadcaster and refresh loop

- [x] 3.1 Increase `UPDATE_CHANNEL` buffer size from 100 to 500 in `event_broadcaster.cr`
- [x] 3.2 Fix `refresh_loop.cr` to keep empty-item feeds in `fetched_map` (change `if data && !data.items.empty?` to `if data`)
- [x] 3.3 Fix `build_tab_feeds()` to only substitute error placeholder for truly failed feeds (`nil` result), not feeds with empty items
- [x] 3.4 Fix `admin_controller.cr` KeyError: change `broadcaster_stats["sent"]` to `broadcaster_stats["processed"]`

## 4. Backend: Verify build and tests

- [x] 4.1 Run `nix develop . --command crystal build --release src/quickheadlines.cr -o bin/quickheadlines` to verify backend compiles
- [x] 4.2 Run `nix develop . --command crystal spec` to verify backend tests pass
- [x] 4.3 Run `nix develop . --command ameba --fix` to check linting
