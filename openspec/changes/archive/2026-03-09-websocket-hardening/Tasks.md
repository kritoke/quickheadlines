# WebSocket Hardening - Critical Fixes

## Overview
Address remaining WebSocket stability issues identified in code review.

## Tasks

### Backend (Crystal)
- [x] 1.1 Add channel timeout in EventBroadcaster.notify_feed_update
- [x] 1.2 Add heartbeat activity tracking to Connection (via separate hash)
- [x] 1.3 Update cleanup_dead_connections to check for stale connections (120s timeout)
- [x] 1.4 Update writer_fiber to track last_activity timestamp

### Frontend (Svelte)
- [x] 2.1 Fix frontend error handler - trigger reconnect on error
- [x] 2.2 Track intentional closes to avoid incrementing consecutiveFailures
- [x] 2.3 Reset intentionalClose flag after close

### Testing
- [ ] 3.1 Add race condition test for concurrent registrations
- [ ] 3.2 Add channel timeout test for EventBroadcaster
- [ ] 3.3 Add stale connection detection test
- [ ] 3.4 Add frontend reconnection logic test

### Build & Verification
- [x] 4.1 Run just nix-build - SUCCESS
- [ ] 4.2 Run Crystal tests
- [ ] 4.3 Manual testing with WebSocket enabled

## Changes Made

### Backend Changes

1. **EventBroadcaster.notify_feed_update** (src/websocket/event_broadcaster.cr:25-41)
   - Added 10ms timeout on channel send
   - Prevents blocking refresh loop when channel buffer is full
   - Logs dropped events

2. **SocketManager Activity Tracking** (src/websocket/socket_manager.cr)
   - Added `@last_activity` hash to track last activity per connection
   - Added `@activity_mutex` for thread-safe access
   - Added `STALE_CONNECTION_AGE = 120` constant

3. **SocketManager.register** (src/websocket/socket_manager.cr:39-65)
   - Initializes last_activity timestamp on registration

4. **SocketManager.writer_fiber** (src/websocket/socket_manager.cr:67-93)
   - Updates last_activity after each successful send

5. **SocketManager.unregister_connection** (src/websocket/socket_manager.cr:95-111)
   - Cleans up last_activity entry when connection is removed

6. **SocketManager.cleanup_dead_connections** (src/websocket/socket_manager.cr:186-245)
   - Now checks for stale connections (no activity for > 120 seconds)
   - Removes both closed websockets AND inactive connections
   - Logs stale connection detection

### Frontend Changes

1. **Connection.intentionalClose flag** (frontend/src/lib/websocket/connection.svelte.ts:16)
   - Tracks whether close was intentional (disconnect() call)

2. **Connection.onerror handler** (frontend/src/lib/websocket/connection.svelte.ts:63-68)
   - Now calls ws.close() to trigger onclose and reconnect logic
   - Prevents connection from staying in 'error' state indefinitely

3. **Connection.onclose handler** (frontend/src/lib/websocket/connection.svelte.ts:70-92)
   - Only increments consecutiveFailures if NOT intentionalClose
   - Resets intentionalClose flag after processing

4. **Connection.disconnect function** (frontend/src/lib/websocket/connection.svelte.ts:94-103)
   - Sets intentionalClose = true before closing
   - Prevents false failure counting

## Impact

These changes address:
1. **Channel backpressure** - No longer blocks refresh loop
2. **Stale connections** - Detected and removed after 120s inactivity
3. **Error recovery** - Automatic reconnection on WebSocket errors
4. **False failures** - Intentional disconnects don't count toward polling fallback
