## Why

The current frontend implementation uses a complex dual WebSocket + long-polling fallback system that adds unnecessary complexity, maintenance overhead, and potential race conditions. We want to commit to WebSocket-only communication for real-time feed updates to simplify the codebase, improve maintainability, and reduce cognitive load for developers.

## What Changes

- **REMOVE** all long-polling fallback logic from WebSocket connection management
- **REMOVE** polling infrastructure including `/api/events` endpoint usage in frontend
- **SIMPLIFY** WebSocket reconnection logic from exponential backoff with jitter to fixed 3-second delay
- **CONSOLIDATE** to a single shared WebSocket connection instance across the entire application
- **REMOVE** `use_websocket` configuration option (WebSocket always enabled)
- **REMOVE** duplicate WebSocket creation logic between feed and timeline pages
- **UPDATE** page components to rely exclusively on WebSocket events for real-time updates
- **CLEANUP** unused polling-related state management and effects

## Capabilities

### New Capabilities
- `websocket-connection`: Centralized WebSocket connection management with simplified reconnection logic

### Modified Capabilities
- `real-time-updates`: Update requirements to specify WebSocket-only communication instead of dual approach

## Impact

- **Files affected**: 
  - `src/lib/websocket/connection.svelte.ts` (complete rewrite)
  - `src/lib/stores/effects.svelte.ts` (major cleanup)
  - `src/routes/+page.svelte` (remove polling logic)
  - `src/routes/timeline/+page.svelte` (remove polling logic)
  - `src/lib/api.ts` (remove polling-related functions)
- **APIs**: Remove dependency on `/api/events` long-polling endpoint
- **Dependencies**: No new dependencies, but simplified WebSocket handling
- **Configuration**: Remove `use_websocket` option from feeds.yml integration
- **Testing**: Update tests to focus on WebSocket-only scenarios