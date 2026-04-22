# WebSocket Hardening Summary

## Issues Fixed

### Backend (Crystal)

#### 1. EventBroadcaster Channel Backpressure
**File:** `src/websocket/event_broadcaster.cr:25-41`

**Problem:** `UPDATE_CHANNEL.send(event)` blocked indefinitely if channel buffer (100) filled up, potentially blocking entire refresh loop.

**Solution:** Added 10ms timeout using `select`:
```crystal
select
when UPDATE_CHANNEL.send(event)
  PROCESSED_EVENTS.add(1)
when timeout(10.milliseconds)
  DROPPED_EVENTS.add(1)
  STDERR.puts "[EventBroadcaster] Channel full, dropping event (buffer size: 100)"
end
```

**Impact:** Refresh loop no longer blocks; events dropped gracefully when system overloaded.

---

#### 2. Stale Connection Detection
**File:** `src/websocket/socket_manager.cr`

**Problem:** Dead connections lingered 30-90 seconds before cleanup (janitor ran every 60s, no activity tracking).

**Solution:** 
- Added `@last_activity` hash to track last message send time per connection
- Updated `writer_fiber` to update timestamp after each send
- Updated `cleanup_dead_connections` to check for connections inactive > 120 seconds

**Impact:** Stale connections detected and removed proactively, reducing resource waste.

**Implementation:**
- New constants: `STALE_CONNECTION_AGE = 120` seconds
- New tracking: `@last_activity : Hash(HTTP::WebSocket, Time)`
- Updated `register()` to initialize timestamp
- Updated `writer_fiber()` to update timestamp after send
- Updated `cleanup_dead_connections()` to check stale connections
- Updated `unregister_connection()` to clean up timestamp

---

### Frontend (Svelte/TypeScript)

#### 3. Error Handler Not Triggering Reconnect
**File:** `frontend/src/lib/websocket/connection.svelte.ts:63-71`

**Problem:** `onerror` only set state to 'error', never triggered reconnect logic.

**Solution:** Force close WebSocket on error to trigger `onclose` handler:
```typescript
ws.onerror = (error) => {
  console.error('[WebSocket] Error:', error);
  state = 'error';
  // Force close to trigger onclose and reconnect logic
  if (ws) {
    ws.close();
  }
};
```

**Impact:** Connection errors now properly trigger reconnection attempts.

---

#### 4. Intentional Closes Counted as Failures
**File:** `frontend/src/lib/websocket/connection.svelte.ts:13,68-104`

**Problem:** Every `onclose` incremented `consecutiveFailures`, even intentional `disconnect()` calls, potentially triggering polling fallback prematurely.

**Solution:** 
- Added `intentionalClose` flag
- `disconnect()` sets flag to `true` before closing
- `onclose` only increments `consecutiveFailures` when flag is `false`
- Flag reset after each close

**Impact:** Users can disconnect/reconnect without triggering polling fallback.

---

## Testing Recommendations

### High Priority
1. **Stale connection detection test**
   - Create connection, wait 130 seconds
   - Verify janitor removes it
   - Verify last_activity tracking works

2. **Channel backpressure test**
   - Fill channel buffer (100 events)
   - Verify next event drops with timeout
   - Verify no blocking

3. **Frontend reconnection test**
   - Trigger error on WebSocket
   - Verify `onclose` called
   - Verify reconnection attempted

4. **Intentional close test**
   - Call `disconnect()`
   - Call `connect()`
   - Verify `consecutiveFailures` not incremented

### Medium Priority
5. **Race condition test**
   - Concurrent registrations at exact MAX_CONNECTIONS limit
   - Verify no exceeding limit

6. **Multi-tab coordination test**
   - Open 5 tabs
   - Verify connection count
   - Consider BroadcastChannel API implementation

---

## Metrics to Monitor

1. **EventBroadcaster dropped events** (`/api/status`)
   - `broadcaster_dropped` should be 0 or very low
   - High values indicate channel overflow

2. **WebSocket dropped messages** (`/api/status`)
   - `websocket_messages_dropped` indicates slow clients
   - High values suggest network issues or client problems

3. **Stale connection cleanup**
   - Check logs for "Stale connection detected"
   - High frequency suggests clients not receiving heartbeats

4. **Connection lifetime**
   - Track average connection duration
   - Very short durations suggest connection issues

---

## Build Status
✅ **just nix-build** - SUCCESS (2025-03-07 12:48)
✅ All fixes compiled successfully
✅ No syntax errors
