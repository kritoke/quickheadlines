## 1. WebSocket Connection Implementation

- [x] 1.1 Create shared WebSocket connection instance in `src/lib/websocket/connection.svelte.ts`
- [x] 1.2 Implement simplified reconnection logic with fixed 3-second delay
- [x] 1.3 Remove all polling fallback logic and state management
- [x] 1.4 Implement centralized event dispatcher for WebSocket messages
- [x] 1.5 Add proper cleanup and memory management for connection lifecycle

## 2. Effects System Cleanup

- [x] 2.1 Remove all polling-related functions from `src/lib/stores/effects.svelte.ts`
- [x] 2.2 Remove `pollTimeout` and polling interval handling
- [x] 2.3 Simplify `createFeedEffects()` to only use WebSocket connection
- [x] 2.4 Simplify `createTimelineEffects()` to only use WebSocket connection
- [x] 2.5 Remove duplicate WebSocket creation logic between feed and timeline effects
- [x] 2.6 Update effects to use centralized WebSocket event handling

## 3. Feed Page Component Updates

- [x] 3.1 Remove polling logic from `src/routes/+page.svelte` `$effect` block
- [x] 3.2 Remove `fetchStatus()` clustering checks and replace with WebSocket events
- [x] 3.3 Remove manual refresh intervals and configuration checking
- [x] 3.4 Update component to use WebSocket events for real-time updates
- [x] 3.5 Simplify cleanup logic to only handle WebSocket disconnection
- [x] 3.6 Remove `abortController` and timeout logic for feed loading

## 4. Timeline Page Component Updates

- [x] 4.1 Remove polling logic from `src/routes/timeline/+page.svelte` `$effect` block  
- [x] 4.2 Remove long-polling implementation for feed updates
- [x] 4.3 Remove `fetchStatus()` clustering checks and replace with WebSocket events
- [x] 4.4 Remove manual refresh intervals and configuration checking
- [x] 4.5 Update component to use WebSocket events for real-time updates
- [x] 4.6 Simplify cleanup logic to only handle WebSocket disconnection
- [x] 4.7 Remove `abortController` and timeout logic for timeline loading

## 5. API Layer Cleanup

- [x] 5.1 Remove `/api/events` endpoint usage from `src/lib/api.ts`
- [x] 5.2 Remove polling-related functions and error handling
- [x] 5.3 Keep only direct REST API calls for initial data loading
- [x] 5.4 Update API documentation comments to reflect WebSocket-only approach

## 6. Configuration and Testing Updates

- [x] 6.1 Remove `use_websocket` configuration option from frontend integration
- [x] 6.2 Update any relevant tests to focus on WebSocket-only scenarios
- [x] 6.3 Remove unused polling-related test cases
- [x] 6.4 Add tests for WebSocket reconnection and event handling
- [x] 6.5 Verify WebSocket-only functionality works in both feed and timeline views

## 7. Final Cleanup and Verification

- [x] 7.1 Remove any remaining unused polling code and imports
- [x] 7.2 Verify no references to long-polling or `/api/events` exist
- [x] 7.3 Test WebSocket reconnection behavior with network interruptions
- [x] 7.4 Verify proper cleanup when navigating between pages
- [x] 7.5 Confirm simplified connection states work correctly (`connecting`, `connected`, `disconnected`)
- [x] 7.6 Run build and ensure no compilation errors