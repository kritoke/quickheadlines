## ADDED Requirements

### Requirement: Timeline effects cleanup on unmount
When the timeline page component is unmounted (user navigates away), all intervals and WebSocket listeners created by `createTimelineEffects()` SHALL be cleaned up to prevent memory leaks.

#### Scenario: Timeline page navigation cleans up effects
- **WHEN** user navigates to the timeline page
- **AND** `createTimelineEffects().start()` is called, setting up intervals and WebSocket listener
- **THEN** when navigating away, `timelineEffects.stop()` is called
- **AND** all intervals are cleared via `clearInterval()`
- **AND** the WebSocket listener is removed via `websocketConnection.removeEventListener()`

#### Scenario: Multiple timeline visits do not accumulate intervals
- **WHEN** user visits the timeline page, leaves, and visits again
- **THEN** there are no duplicate intervals running
- **AND** there are no duplicate WebSocket listeners registered

### Requirement: No dead event listeners
Components SHALL NOT register event listeners that are never removed or that have empty handler functions.

#### Scenario: All registered listeners have actual handlers
- **WHEN** an event listener is registered (e.g., `document.addEventListener('visibilitychange', ...)`)
- **THEN** the handler function performs a meaningful action
- **AND** the listener is removed when the component unmounts or the effect cleanup runs

### Requirement: Feed page does not register duplicate WebSocket listeners
The feed page (`+page.svelte`) SHALL NOT register its own WebSocket listener if `createFeedEffects()` already handles WebSocket message dispatching. WebSocket updates SHALL be handled by a single listener to prevent duplicate fetch operations.

#### Scenario: Single WebSocket listener handles feed updates
- **WHEN** `createFeedEffects().start()` is called on the feed page
- **AND** it registers a listener for `feed_update` messages
- **THEN** the page component does NOT register a separate listener for the same message type
- **AND** a single feed update message triggers exactly one `loadFeeds()` call
