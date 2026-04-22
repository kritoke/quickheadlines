## Context

The current WebSocket implementation in QuickHeadlines has critical stability issues:

1. **Thread-safety violation**: `SocketManager.broadcast` holds `@connections_mutex` while calling `ws.send()`, blocking all register/unregister operations during broadcasts
2. **Mutation during iteration**: Dead connections are deleted from `@connections` Set while iterating in broadcast loop
3. **No backpressure**: EventBroadcaster channel can fill up, blocking the refresh loop
4. **No connection limits**: No max connections or per-IP limits, vulnerable to DoS
5. **Poor error handling**: Generic rescues hide error types, no structured logging

These issues can cause complete outages when a slow client connects or during high load.

## Goals / Non-Goals

**Goals:**
- Fix thread-safety: broadcast must not hold mutex during I/O
- Prevent mutation during iteration
- Add bounded per-connection queues with backpressure
- Add connection limits (global and per-IP)
- Improve error logging with exception details
- Add Janitor fiber for dead connection cleanup
- Add frontend reconnection jitter

**Non-Goals:**
- Change the WebSocket protocol or message format
- Add authentication/authorization (not required for public feed reader)
- Implement horizontal scaling (single instance only)
- Add WebSocket compression (future enhancement)

## Decisions

### D1: Per-Connection Writer Fibers

**Decision**: Implement a dedicated writer fiber for each WebSocket connection with a bounded outgoing Channel.

**Rationale**:
- Serializes all writes to a single connection, avoiding concurrent writes
- Provides natural backpressure: if channel is full, sender can drop/close
- Isolates slow clients from affecting broadcast performance

**Alternative considered**: Use a thread pool for sends. Rejected because WebSocket writes must be ordered per-connection anyway.

### D2: Copy-On-Broadcast Pattern

**Decision**: Copy connections to a local array under lock, release lock, then iterate without holding lock.

**Rationale**:
- Minimal code change that fixes the immediate mutex issue
- Allows I/O without blocking register/unregister
- Simple and proven pattern

**Alternative considered**: Use reader-writer lock. More complex; writer fiber approach already provides serialization.

### D3: Bounded Channel for Outgoing Messages

**Decision**: Each connection has a `Channel(String)` with configurable size (default: 10).

**Rationale**:
- If client is slow, queue fills up quickly
- Can implement "drop oldest" or "close connection" policy
- Prevents memory exhaustion from slow clients

**Size choice**: 10 messages provides enough buffer for burst updates while limiting memory per connection to ~10KB assuming 1KB average message size.

### D4: Non-Blocking Channel Sends in EventBroadcaster

**Decision**: Use `try_send` or spawn a fiber for each broadcast to avoid blocking the producer.

**Rationale**:
- Refresh loop must not be blocked by slow WebSocket clients
- If channel is full, log warning and continue (event can be coalesced)

**Alternative considered**: Unbounded channel. Rejected - can cause memory exhaustion.

### D5: Connection Limits via Config

**Decision**: Add configuration options `max_connections` (default: 1000) and `max_connections_per_ip` (default: 10).

**Rationale**:
- Protects against DoS from single IP
- Global limit prevents file descriptor exhaustion
- Configurable for different deployment sizes

### D6: Janitor Fiber for Cleanup

**Decision**: Add a periodic fiber that checks connection health every 60 seconds.

**Rationale**:
- Handles cases where on_close is not delivered (unclean disconnect)
- Can detect stale connections via ping/pong if needed
- Low overhead (single fiber, simple check)

### D7: Frontend Reconnection Jitter

**Decision**: Add random jitter (0.5-1.5x multiplier) to reconnection delay.

**Rationale**: Prevents thundering herd when server restarts - all clients won't reconnect at exactly the same time.

## Risks / Trade-offs

- [Risk] Increased memory per connection due to writer channel. → Mitigation: Small channel size (10), enforce global connection limit.
- [Risk] More fibers = more scheduler overhead. → Mitigation: Limit max connections to reasonable number (1000).
- [Risk] Janitor may mark healthy connection as dead under high load. → Mitigation: Use lenient timeout, only cleanup on clear failure.
- [Risk] Dropping messages during backpressure loses updates. → Mitigation: Updates are frequent (every 30s-10min), clients will fetch on next poll anyway.

## Migration Plan

1. Add new config options with safe defaults (backward compatible)
2. Deploy new SocketManager with copy-on-broadcast fix
3. Add per-connection writer fibers incrementally
4. Add connection limits after testing
5. Deploy frontend with jitter

No rollback needed - all changes are backward compatible.

## Open Questions

- Should we implement ping/pong for connection liveness? (deferred to future)
- Should we expose WebSocket metrics via /api/status? (deferred to future)
