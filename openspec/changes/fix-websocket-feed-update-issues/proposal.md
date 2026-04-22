## Why

WebSocket-triggered feed updates are failing to reliably refresh the UI due to several implementation bugs: race conditions in the timeline refresh guard, scroll restoration timing issues with async fetches, event drops in the broadcaster, and periodic polling that duplicates WebSocket work. These bugs violate the existing `real-time-updates` and `websocket-connection` specs.

## What Changes

1. **Fix timeline refresh guard race condition** — Add a `force` parameter to `loadTimeline()` that bypasses the loading/refreshing guard for WebSocket-triggered refreshes, ensuring WebSocket pushes always trigger a refresh
2. **Fix scroll restoration race** — Await async fetches before restoring scroll position in `handleFeedUpdate`
3. **Fix EventBroadcaster event drops** — Increase channel buffer or use non-blocking send with latest-only dedup so clients always receive the most recent update
4. **Remove redundant periodic polling** — Eliminate `setInterval` refresh timers in `createFeedEffects`/`createTimelineEffects` since WebSocket `feed_update` is the sole transport per the `websocket-connection` spec
5. **Wire up clustering_status WebSocket broadcast** — Backend should broadcast `clustering_status` when clustering starts/completes so the UI gets a push instead of relying on polling
6. **Keep cached feed data on temporary empty responses** — When a feed returns 0 items (transient failure), retain the previous cached data instead of replacing with an error placeholder
7. **Fix admin status endpoint KeyError** — Change `broadcaster_stats["sent"]` to `broadcaster_stats["processed"]`

## Capabilities

### New Capabilities
- `websocket-feed-refresh`: Coordinates WebSocket-triggered feed/timeline refreshes with proper async handling, debouncing, and scroll preservation
- `clustering-websocket-broadcast`: Backend broadcasts clustering status over WebSocket so frontend doesn't need to poll for it

### Modified Capabilities
- `websocket-connection`: The current implementation includes `setInterval` polling that violates the "WebSocket-only communication" requirement. The periodic polling in `createFeedEffects`/`createTimelineEffects` must be removed. Spec unchanged but implementation must align.
- `real-time-updates`: The `feed_update` handler's async race conditions and scroll restoration timing violate the "triggers appropriate data refreshes" requirement. Implementation fixes required; spec language may be clarified.

## Impact

### Frontend
- `frontend/src/lib/stores/timelineStore.svelte.ts` — `loadTimeline()` needs `force` parameter
- `frontend/src/lib/stores/effects.svelte.ts` — Remove polling intervals, await async fetches, add debounce
- `frontend/src/lib/stores/feedStore.svelte.ts` — No changes, but existing `force` param on `loadFeeds()` already correct

### Backend
- `src/websocket/event_broadcaster.cr` — Increase buffer or add non-blocking latest-only broadcast
- `src/fetcher/refresh_loop.cr` — Preserve cached feed data on transient empty-item responses
- `src/websocket/event_broadcaster.cr` — Add `clustering_status` broadcast when clustering state changes
- `src/controllers/admin_controller.cr` — Fix KeyError on `broadcaster_stats["sent"]`

### API
- No API changes; all fixes are implementation-level
