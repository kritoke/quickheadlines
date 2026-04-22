## Context

The current frontend implementation uses a complex dual approach for real-time updates: WebSocket connections with long-polling fallback. This creates significant complexity in the codebase with duplicated logic, intricate state management, and potential race conditions. The system tracks consecutive failures, implements exponential backoff with jitter, maintains separate polling mechanisms, and handles configuration-driven switching between transport methods.

Key pain points:
- **Code duplication**: Similar WebSocket logic in both feed and timeline pages
- **Complex state management**: Multiple connection states (`connecting`, `connected`, `disconnected`, `error`, `polling`)
- **Over-engineering**: Exponential backoff, jitter, failure tracking for a simple RSS reader
- **Maintenance overhead**: Dual transport mechanisms require testing and debugging both paths
- **Performance**: Unnecessary polling when WebSocket is available

## Goals / Non-Goals

**Goals:**
- Simplify to WebSocket-only communication for real-time feed updates
- Reduce code complexity by 50% in connection management
- Eliminate race conditions and state inconsistencies
- Improve maintainability and developer experience
- Maintain reliable reconnection behavior
- Ensure proper cleanup and memory management

**Non-Goals:**
- Implement new features or capabilities
- Change the WebSocket protocol or message format
- Modify backend WebSocket implementation
- Add support for other real-time transport methods
- Handle offline scenarios beyond basic reconnection

## Decisions

### 1. Single Shared WebSocket Connection
**Decision**: Create one shared WebSocket connection instance for the entire application instead of per-page connections.

**Rationale**: Both feed and timeline pages need the same feed update events. Having separate connections duplicates network requests and complicates state management. A single connection reduces resource usage and ensures consistent state across the application.

**Alternative Considered**: Keep per-page connections for isolation. 
**Why Rejected**: Overkill for this use case; adds complexity without benefit.

### 2. Fixed Reconnection Delay
**Decision**: Use fixed 3-second reconnection delay instead of exponential backoff with jitter.

**Rationale**: The application is an RSS reader where immediate updates are nice but not critical. A simple fixed delay is easier to understand, debug, and maintain. Users won't notice the difference between 1s, 2s, or 3s reconnection delays.

**Alternative Considered**: Keep exponential backoff (1s, 2s, 4s, 8s, 16s, 30s max).
**Why Rejected**: Adds unnecessary complexity for minimal user benefit.

### 3. Centralized Event Handling
**Decision**: Handle all WebSocket events centrally and dispatch to appropriate stores/components.

**Rationale**: Centralized event handling ensures consistent processing of feed updates regardless of which page is active. This avoids duplicate logic and ensures that both feed and timeline views stay synchronized.

**Alternative Considered**: Handle events in each page component separately.
**Why Rejected**: Would require duplicating event handling logic and could lead to inconsistent state.

### 4. Remove All Polling Infrastructure
**Decision**: Completely remove long-polling fallback and `/api/events` endpoint usage.

**Rationale**: Modern browsers have excellent WebSocket support. The fallback was likely added for very old browsers or specific edge cases that are no longer relevant. Removing it eliminates a significant source of complexity.

**Alternative Considered**: Keep minimal polling as emergency fallback.
**Why Rejected**: Adds maintenance burden without clear benefit; if WebSocket fails completely, the app should just show connection status.

### 5. Simplified Connection State
**Decision**: Reduce connection states to only `connecting`, `connected`, and `disconnected`.

**Rationale**: The `error` and `polling` states are unnecessary. Errors can be logged and handled by transitioning to `disconnected` and attempting reconnection. Since we're removing polling, the `polling` state is obsolete.

**Alternative Considered**: Keep detailed error states for better UX.
**Why Rejected**: Overcomplicates the state machine; simple "connecting/connected/disconnected" is sufficient for user feedback.

## Risks / Trade-offs

**[Risk] WebSocket connection failures in restrictive networks** → **Mitigation**: Provide clear connection status UI showing "Connecting..." state; users can refresh if needed.

**[Risk] Memory leaks from improper cleanup** → **Mitigation**: Implement strict cleanup in `$effect` return functions and ensure single connection instance is properly managed.

**[Risk] Race conditions during rapid reconnections** → **Mitigation**: Use a single connection instance with proper closure before reconnection attempts.

**[Risk] Breaking changes for users with very old browsers** → **Mitigation**: Document browser requirements; modern browsers (last 5 years) all support WebSocket reliably.

**[Risk] Loss of clustering status updates** → **Mitigation**: Extend WebSocket events to include clustering status, or handle clustering through the same feed update mechanism.

**[Trade-off] Simpler code vs. robustness** → **Acceptance**: The simplified approach is more maintainable and the reduced robustness is acceptable for an RSS reader application.