## Why

The current WebSocket implementation has critical thread-safety and resource management issues that can cause outages under load. The broadcast method holds a mutex during I/O operations, preventing connection registration/unregistration during broadcasts. Additionally, unbounded message queues and lack of connection limits create DoS vulnerabilities. These issues must be fixed before the WebSocket feature can be considered production-ready.

## What Changes

1. **Fix broadcast thread-safety**: Copy connections under lock, release lock, then send messages without holding mutex
2. **Fix mutation-during-iteration**: Collect dead connections during iteration, remove after iteration completes
3. **Add per-connection writer fibers**: Implement bounded outgoing queues per connection with backpressure
4. **Handle channel full case**: Use non-blocking sends or handle backpressure in EventBroadcaster
5. **Add connection limits**: Implement max_connections config and per-IP limits
6. **Improve error logging**: Include exception class and backtrace for debugging
7. **Add Janitor fiber**: Periodic cleanup of dead/stale connections
8. **Add frontend reconnection jitter**: Spread reconnections to prevent thundering herd

## Capabilities

### New Capabilities
- `websocket-connection-management`: Per-connection writer fibers with bounded queues and backpressure
- `websocket-resource-limits`: Connection limits and per-IP rate limiting
- `websocket-heartbeat`: Per-connection ping/pong for connection liveness detection
- `websocket-graceful-degradation`: Frontend jitter and fallback polling behavior

### Modified Capabilities
- `websocket-updates`: Existing spec modified to add stability requirements (bounded queues, error handling)

## Impact

- **Code**: src/websocket/socket_manager.cr, src/websocket/event_broadcaster.cr, frontend/src/lib/websocket/connection.svelte.ts
- **Config**: Add max_connections, max_connections_per_ip, connection_queue_size to Config
- **API**: No external API changes; internal stability improvements only
- **Dependencies**: None (Crystal stdlib only)
