## Why

Address remaining Medium and Low severity bugs identified in the code review that improve code quality, consistency, and edge-case handling.

## What Changes

1. **Performance**: Batch DELETE in cleanup-orphaned admin action (N+1 → single query)
2. **Performance**: Batch INSERT in `FeedRepository.insert_items` (N+1 → single statement)
3. **Performance**: Add LIMIT to `ClusterRepository.find_all` to prevent unbounded memory growth
4. **Bug**: `HeartbeatEvent` uses `Time.local` instead of `Time.utc` (inconsistency)
5. **Bug**: `UrlNormalizer.normalize` always adds trailing slash (can cause URL mismatches)
6. **Edge case**: `proxy_controller` `max=0` silently rejects all images
7. **Cleanup**: Remove remaining `console.log` from `timelineStore.svelte.ts`

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- None — all fixes are implementation details

## Impact

- `AdminController` (cleanup-orphaned batch delete)
- `FeedRepository` (batch insert for items)
- `ClusterRepository` (pagination for find_all)
- `EventBroadcaster` (Time.utc for heartbeat)
- `utils.cr` (UrlNormalizer normalize)
- `ProxyController` (max parameter validation)
- `timelineStore.svelte.ts` (console.log removal)