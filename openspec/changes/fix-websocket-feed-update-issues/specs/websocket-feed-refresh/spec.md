# websocket-feed-refresh Specification

## Purpose
Coordinates WebSocket-triggered feed and timeline refreshes with proper async handling, debouncing, and scroll position preservation. Ensures that `feed_update` WebSocket messages reliably update the UI without race conditions or lost updates.

## ADDED Requirements

### Requirement: feed_update message triggers data refresh
When a `feed_update` WebSocket message is received with a timestamp newer than the last received update, the frontend SHALL fetch fresh data from both `/api/feeds` and `/api/timeline`.

#### Scenario: feed_update received while idle
- **WHEN** a `feed_update` message arrives and its timestamp exceeds the last known update timestamp
- **THEN** fresh feed data and timeline data are fetched from the API

#### Scenario: feed_update deduplication
- **WHEN** a `feed_update` message arrives with a timestamp that is not newer than the last known update
- **THEN** the message is ignored and no data refresh occurs

### Requirement: Refresh operations are awaited before scroll restoration
The frontend SHALL await all data fetch operations before restoring the user's scroll position, preventing scroll jumps during live updates.

#### Scenario: Scroll preserved during feed update
- **WHEN** a `feed_update` message triggers a data refresh
- **THEN** the current scroll position is captured, data is fetched, DOM updates are flushed, and then scroll position is restored

### Requirement: Debounced refresh for rapid events
If multiple `feed_update` messages arrive within a 500ms window, the frontend SHALL cancel any pending refresh and schedule a single consolidated refresh, preventing redundant concurrent requests.

#### Scenario: Rapid consecutive updates
- **WHEN** a second `feed_update` message arrives within 500ms of a previous unacknowledged `feed_update`
- **THEN** the pending refresh is cancelled and a new debounced refresh is scheduled

#### Scenario: Steady update stream
- **WHEN** `feed_update` messages arrive with more than 500ms between them
- **THEN** each message triggers its own independent refresh

### Requirement: Force refresh bypasses loading guards
When triggered by a WebSocket `feed_update`, the refresh operation SHALL bypass any loading/refreshing state guards to ensure the update is not silently dropped.

#### Scenario: Refresh while timeline is already loading
- **WHEN** a `feed_update` arrives while a previous load is still in progress
- **THEN** the new refresh is executed anyway (force refresh), replacing stale in-flight data
