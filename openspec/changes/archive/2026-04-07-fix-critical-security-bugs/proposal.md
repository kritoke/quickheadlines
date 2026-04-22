## Why

The codebase has 4 critical-severity issues (unauthenticated write endpoint, clustering race condition, WebSocket IP count double-decrement, broken cluster pagination) and 4 high-severity issues that must be fixed before production deployment.

## What Changes

1. **Security fix**: Add auth check to `HeaderColorController#save_header_color` (critical)
2. **Security fix**: Add rate limiting to `FeedPaginationController#feed_more` (high)
3. **Bug fix**: Unify clustering state mutex to prevent concurrent clustering (critical)
4. **Bug fix**: Fix `cleanup_dead_connections` to not double-decrement IP counts (critical)
5. **Bug fix**: Fix `count_timeline_items` to match representative filter in `find_timeline_items` (critical)
6. **Bug fix**: Fix `EventBroadcaster.PROCESSED_EVENTS` double-count (high)
7. **Bug fix**: Add transaction safety to admin `clear-cache` action (high)
8. **Bug fix**: Add Time::Format::Error handling in repository time parsing (high)
9. **Code cleanup**: Remove console.log statements from production frontend code (low)

## Capabilities

### New Capabilities
- None — all fixes are bug fixes to existing behavior

### Modified Capabilities
- `api-endpoints`: The `/api/header_color` POST endpoint now requires admin auth
- `websocket-connections`: IP connection count tracking is corrected; no longer double-decrements
- `timeline-pagination`: `count_timeline_items` now correctly counts visible (representative) items only

## Impact

- **Controllers**: `HeaderColorController`, `FeedPaginationController`, `AdminController`
- **Models**: `StateStore` (clustering mutex)
- **WebSocket**: `SocketManager` (IP counting), `EventBroadcaster` (stats)
- **Repositories**: `StoryRepository` (count query, time parsing)
- **Frontend**: Remove debug console.log from `api.ts`, `feedStore.svelte.ts`