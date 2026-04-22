# Proposal: WebSocket Real-Time Updates

## Why

QuickHeadlines currently uses HTTP long-polling (`/api/events`) to detect feed updates. Every 31 seconds, each connected client creates a new HTTP request that holds a fiber for up to 30 seconds, checking if `STATE.updated_at` has changed. This creates unnecessary CPU and network overhead: ~3,480 polling iterations and ~93KB of HTTP headers per client per hour, even when no updates occur.

**The solution**: Replace polling with WebSocket push notifications. When feeds update, broadcast to all connected clients instantly via WebSocket. This reduces CPU by 74x, network by 100-1000x, and provides instant update notifications (<100ms vs 1-30s latency).

## What Changes

1. **New WebSocket infrastructure**:
   - `SocketManager` - Thread-safe singleton managing active WebSocket connections
   - `EventBroadcaster` - Channel-based pub/sub for broadcasting updates
   - WebSocket handler integrated via `ATH.run(prepend_handlers: [ws_handler])`

2. **Backend modifications**:
   - Add `/api/ws` WebSocket endpoint (upgrade from `/api/events` polling)
   - Modify `refresh_all` to broadcast `FeedUpdateEvent` when STATE updates
   - Add `StoryRepository.prune_old_stories(days)` for 14-day retention
   - Add Janitor background fiber (runs every 6 hours)
   - Feature flag `use_websocket` in config (default: false)

3. **Frontend modifications**:
   - New `createLiveConnection` Svelte 5 rune managing WebSocket lifecycle
   - Replace polling effects with WebSocket-based live updates
   - Add connection status indicator (always visible, green dot when connected)
   - Add `data-name` attributes to all major UI components

4. **No fetcher changes**:
   - Continue using existing `fetcher` shard (kritoke/fetcher.cr) maintained by user
   - No new packages/fetcher needed

## Capabilities

### New Capabilities
- **websocket-updates**: Push-based real-time feed updates via WebSocket instead of HTTP long-polling
- **connection-status**: Visual indicator showing WebSocket connection state
- **auto-reconnect**: Exponential backoff reconnection when WebSocket disconnects

### Modified Capabilities
- **feed-refresh**: Behavior unchanged (periodic refresh), but now broadcasts via WebSocket instead of requiring clients to poll
- **story-retention**: Existing 14-day retention already configurable; adds explicit `prune_old_stories` method

## Impact

**Backend**:
- `/src/websocket/` - New directory with SocketManager, EventBroadcaster
- `/src/controllers/api_controller.cr` - Add `/api/ws` endpoint
- `/src/fetcher/refresh_loop.cr` - Broadcast updates after refresh
- `/src/repositories/story_repository.cr` - Add `prune_old_stories` method
- `/src/application.cr` - Add Janitor fiber, EventBroadcaster startup
- `/src/quickheadlines.cr` - Add WebSocket handler to server chain
- `feeds.yml` - Add `use_websocket: false` feature flag

**Frontend**:
- `/frontend/src/lib/websocket/` - New WebSocket connection manager
- `/frontend/src/lib/stores/feedStore.svelte.ts` - Use WebSocket instead of polling
- `/frontend/src/lib/stores/timelineStore.svelte.ts` - Use WebSocket instead of polling
- `/frontend/src/lib/components/AppHeader.svelte` - Add connection status indicator
- All major components - Add `data-name` attributes per constitution

**Dependencies**:
- None (uses Crystal stdlib HTTP::WebSocket)
- No external hubs (Mercure/Redis)
- Single binary deployment maintained
