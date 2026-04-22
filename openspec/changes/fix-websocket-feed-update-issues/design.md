## Context

The system uses WebSocket as the exclusive transport for real-time feed updates (per `real-time-updates` and `websocket-connection` specs). The frontend has two effects systems (`createFeedEffects`, `createTimelineEffects`) that both set up `setInterval` polling AND listen for WebSocket `feed_update` messages. The backend refresh loop broadcasts `FeedUpdateEvent` via `EventBroadcaster` after each refresh cycle.

Several implementation bugs cause WebSocket-triggered updates to fail to refresh the UI reliably.

## Goals / Non-Goals

**Goals:**
- Fix race conditions preventing WebSocket updates from reaching the UI
- Ensure WebSocket is the sole refresh mechanism (remove redundant polling)
- Add clustering status WebSocket broadcast so frontend doesn't need to poll for it
- Fix transient error handling to preserve cached data instead of showing error placeholders

**Non-Goals:**
- No API changes (all fixes are implementation-level)
- No changes to the database schema
- No new external dependencies

## Decisions

### 1. Fix timeline refresh guard with `force` parameter
**Problem:** `timelineStore.loadTimeline()` checks `isRefreshing(timelineState) || isLoading(timelineState)` and returns early. When WebSocket triggers `loadTimeline()` while periodic polling is already running a refresh, the WebSocket event is silently dropped.

**Decision:** Add a `force` parameter to `loadTimeline(append = false, tab?: string, force = false)` that bypasses the loading guard. The `handleFeedUpdate` handler in `effects.svelte.ts` passes `force=true`. This mirrors the existing `loadFeeds(tab, force)` pattern.

**Alternatives considered:**
- Use a mutex/lock: Over-engineered for JavaScript single-threaded context
- Reset state before calling: Would cause UI flicker between clear and reload
- Queue requests: Complex, not needed given single-threaded JS

### 2. Await async fetches before scroll restore; defer scroll to after DOM update
**Problem:** `handleFeedUpdate` calls `loadFeeds()` and `loadTimeline()` without awaiting, then immediately calls `window.scrollTo()`. The scroll fires before the DOM updates from the async fetches.

**Decision:** Await both async calls before restoring scroll. Wrap scroll restoration in `queueMicrotask(() => window.scrollTo(...))` to ensure it fires after Svelte's reactive DOM updates are flushed.

```typescript
async function handleFeedUpdate(timestamp: number) {
    if (timestamp > lastUpdate) {
        lastUpdate = timestamp;
        saveScrollY = window.scrollY;
        await loadFeeds(feedState.activeTab, true);
        await loadTimeline(false, undefined, true);
        queueMicrotask(() => window.scrollTo(0, saveScrollY));
    }
}
```

**Alternatives considered:**
- `setTimeout(0)`: Works but is less idiomatic than `queueMicrotask`
- `requestAnimationFrame`: Also valid but `queueMicrotask` is more direct for "after current task"

### 3. Debounce WebSocket-triggered refreshes
**Problem:** WebSocket `feed_update` + periodic polling can fire close together, causing two concurrent reloads that race (stale response overwriting fresh one).

**Decision:** Add a debounce timer (500ms) in `handleFeedUpdate`. If another `feed_update` arrives within the window, cancel the previous pending reload and start fresh. Use a simple `clearTimeout`/`setTimeout` pattern.

```typescript
let debounceTimer: ReturnType<typeof setTimeout> | null = null;

function handleFeedUpdate(timestamp: number) {
    if (timestamp > lastUpdate) {
        lastUpdate = timestamp;
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(async () => {
            saveScrollY = window.scrollY;
            await loadFeeds(feedState.activeTab, true);
            await loadTimeline(false, undefined, true);
            queueMicrotask(() => window.scrollTo(0, saveScrollY));
        }, 500);
    }
}
```

### 4. Increase EventBroadcaster channel buffer and use non-blocking latest-only dedup
**Problem:** Channel buffer of 100 with 10ms timeout can drop events during burst refreshes. Clients miss `feed_update` notifications entirely.

**Decision:** Increase buffer to 500 and keep timeout at 10ms. Additionally, if the channel is full, instead of just dropping, overwrite with the latest event so clients at least get the most recent update.

```crystal
# Change from: Channel(FeedUpdateEvent).new(100)
UPDATE_CHANNEL = Channel(FeedUpdateEvent).new(500)

# In notify_feed_update, on timeout: 
# Instead of just dropping, if channel is full, replace the oldest 
# pending event with the new one. Since we can't inspect channel contents,
# use a simpler approach: track last timestamp and on next broadcast 
# cycle, if last timestamp >= queued event timestamp, skip the queue 
# and broadcast directly.
```

Actually, the cleanest fix is to not drop at the sender but instead make the channel large enough (500) that it effectively never fills in normal operation. The 10ms timeout means events queue for up to 10ms before being sent. If refreshes happen every 10 minutes normally, but a feeds.yml hot-reload can trigger an extra refresh, the channel would need 6+ events queued in 10ms to drop — unlikely in practice.

**Increase buffer to 500** (from 100) to handle burst scenarios.

### 5. Wire up `clustering_status` WebSocket broadcast
**Problem:** Backend never sends `clustering_status` messages. Frontend has dead code handling it (`effects.svelte.ts:61`). Clustering completion doesn't push UI refresh.

**Decision:** Add a `ClusteringStatusEvent` struct and broadcast it from `EventBroadcaster` when `StateStore.clustering` transitions. The clustering runs asynchronously after `refresh_all`, so we can check `StateStore.clustering` before and after `async_clustering`. Actually, the cleaner approach: broadcast `clustering_status: false` when `async_clustering` completes in `refresh_all`.

In `refresh_loop.cr`, after `async_clustering` spawns, add:
```crystal
# After async_clustering call (around line 115), add:
EventBroadcaster.notify_clustering_update(false)
```

And in `EventBroadcaster`:
```crystal
CLUSTERING_CHANNEL = Channel(Bool).new(10)

def self.notify_clustering_update(is_clustering : Bool) : Nil
  # non-blocking send to clustering channel
end
```

Actually, the simplest approach: since `async_clustering` is already spawned and runs in background, we can broadcast when it completes. But the backend doesn't have a callback mechanism for spawned fibers. The cleanest way is to add a `ClusteringBroadcaster` that tracks state and sends on transition.

Simpler yet: broadcast from the `refresh_all` function after `async_clustering` is called (not waited on). Since `async_clustering` will eventually complete and set `StateStore.clustering = false`, we can poll for this... but that defeats the purpose.

Best approach: Add `ClusteringStatusEvent` to `EventBroadcaster` and call it explicitly when clustering state changes. In `refresh_loop.cr`, call `EventBroadcaster.notify_clustering_update(true)` before spawning `async_clustering`, and add a completion callback to `async_clustering` that broadcasts `false`. But `async_clustering` is spawned without a callback.

Simplest valid fix: In `refresh_loop.cr`, after the `async_clustering(...)` line, immediately broadcast `clustering_status: false`. This won't be exactly when clustering finishes (it's async), but it's close enough and follows the spirit of the spec. The frontend will refresh on the next polling cycle or next `feed_update` anyway.

Actually, the real fix: `async_clustering` should report its completion. We can do this by wrapping the `spawn` in a way that notifies on completion. But that's a larger refactor. 

**Minimum viable fix**: Don't broadcast at all for now, since `feed_update` already fires when the clustering data changes (new items inserted). The timeline will refresh on the next `feed_update`. Remove the dead `clustering_status` handler from the frontend instead.

Wait — the existing `clustering_status` code in the frontend is dead code. The user reported "websockets not updating... when more items are pulled". If we remove the dead code, we don't fix anything. The real issue is that the frontend receives `feed_update` but something else prevents the refresh.

Let me reconsider. The `feed_update` IS broadcast after refresh_all. The frontend receives it and calls `loadFeeds` and `loadTimeline`. But the user says items aren't showing up after being pulled. The root cause is likely the timeline guard race condition, not clustering. The clustering_status dead code is a separate issue.

**Decision**: Skip the clustering_status WebSocket broadcast for now (it's a separate enhancement), fix the timeline guard race instead.

### 6. Preserve cached feed data on transient empty responses
**Problem:** When `data && !data.items.empty?` is false, the feed is replaced with an error placeholder. A transient network hiccup causes 0 items temporarily, replacing a working feed with an error.

**Decision:** In `fetch_feeds_concurrently`, when a feed returns `FeedData` with empty items (not `nil`), keep the previous cached data instead of the error placeholder. Modify `build_tab_feeds` to only use error placeholder when `fetched_map[feed.url]` is absent (truly unfetched) or was `nil` (truly failed).

```crystal
# In fetch_feeds_concurrently (refresh_loop.cr):
fetched_map = channel.receive
# Keep FeedData with empty items in the map (don't skip)
if data  # data can be FeedData with empty items
  fetched_map[data.url] = data
end
# Only log warning for nil (actual failure), not empty items
```

And in `build_tab_feeds`:
```crystal
# Only substitute error if url not in fetched_map at all (not if empty FeedData)
fetched = fetched_map[feed.url]?
tab_feeds = tab_config.feeds.map { |feed| fetched || error_feed_data(feed, "Failed to fetch") }
```

But `error_feed_data` creates a `FeedData` with `is_error: true`. We need to distinguish between "never fetched" and "fetched but empty". 

Better approach: Keep `nil` for failure, `FeedData` (possibly empty) for success. But the channel returns `FeedData | Nil`. The current code already does this — `nil` means failure. The issue is `data && !data.items.empty?` skips non-nil but empty feeds.

**Fix**: Change `if data && !data.items.empty?` to just `if data` in `fetch_feeds_concurrently`. Empty feeds stay in the map as valid `FeedData` with `items: []`. Then in `build_tab_feeds`, only use `error_feed_data` if `fetched_map[feed.url]` is `nil` (never got a result for this URL).

### 7. Fix admin status endpoint KeyError
**Problem:** `admin_controller.cr:164` references `broadcaster_stats["sent"]` but the `EventBroadcaster.stats` method returns keys `"dropped"` and `"processed"`.

**Decision:** Change `broadcaster_stats["sent"]` to `broadcaster_stats["processed"]`.

### 8. Remove redundant periodic polling
**Problem:** `createFeedEffects` and `createTimelineEffects` both set up `setInterval` timers that call `loadFeeds()` and `loadTimeline()` at the same `refresh_minutes` interval the backend already uses. This violates the `websocket-connection` spec's "WebSocket-only communication" requirement and causes double-loads.

**Decision:** Remove the `refreshInterval` `setInterval` from both `createFeedEffects` and `createTimelineEffects`. Keep only the `configInterval` (which adjusts the refresh rate if config changes). WebSocket `feed_update` is the sole refresh trigger.

The `configInterval` serves a different purpose: if `refresh_minutes` changes in the config, it adjusts the next check. Actually, after removing `refreshInterval`, the `configInterval` also has nothing to do since no other code reads `refreshMinutes` from config on the frontend... Wait, the periodic check is what fetches the config to see if `refresh_minutes` changed. But without `refreshInterval`, there's no periodic activity at all.

**Simplify**: Remove both intervals from `createFeedEffects` and `createTimelineEffects`. The WebSocket `feed_update` is the sole mechanism. If the user wants a periodic refresh, that's a separate feature request (and would need a spec change).

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Removing polling breaks users in environments where WebSocket delivery is unreliable | Keep the `connectionState` tracking; if WebSocket disconnects and `onReconnect` fires, data is refreshed. This is sufficient per `websocket-connection` spec. |
| `queueMicrotask` scroll deferral causes subtle timing issues | Test manually with rapid feed updates to verify scroll position is preserved |
| Increasing channel buffer to 500 uses more memory | Acceptable trade-off; 500 events at ~200 bytes each = ~100KB |
| Keeping empty-item feeds in cache could hide real fetch errors | The `is_error: true` flag on `error_feed_data` is still used for `nil` results; empty arrays are a valid (if rare) feed state |
