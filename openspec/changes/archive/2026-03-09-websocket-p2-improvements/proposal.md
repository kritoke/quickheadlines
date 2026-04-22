# Proposal: WebSocket P2 Improvements

## Why

The P0/P1 fixes addressed critical concurrency bugs and basic monitoring. P2 improvements focus on production hardening, frontend resilience, and advanced features that improve the user experience under adverse conditions.

## What Changes

1. **Frontend Reconnection Improvements**:
   - Add jitter to exponential backoff reconnection
   - Cap maximum reconnection attempts
   - Graceful fallback to polling after repeated failures

2. **Advanced Monitoring**:
   - Structured logging with timestamps and context
   - Metrics endpoint for Prometheus integration
   - Per-connection latency tracking

3. **Configuration Externalization**:
   - Move hardcoded values (heartbeat interval, queue size) to feeds.yml
   - Add websocket.max_connections, websocket.queue_size config options

4. **Connection Lifecycle Enhancements**:
   - Per-connection ping/pong heartbeats
   - Automatic re-authentication on connection stale
   - Connection graceful shutdown with drain period

5. **Testing**:
   - WebSocket unit tests for SocketManager broadcast
   - Frontend WebSocket connection tests
   - Load testing with concurrent connections

## Capabilities

### New Capabilities
- **jitter-reconnect**: Randomize reconnection delays to prevent thundering herd
- **polling-fallback**: Automatic fallback to polling when WebSocket fails repeatedly
- **configurable-websocket**: Externalize WebSocket settings to config file
- **metrics-endpoint**: Expose WebSocket metrics for monitoring

### Modified Capabilities
- **status-endpoint**: Add more detailed WebSocket stats

## Impact

**Backend**:
- `/src/config.cr` - Add websocket configuration section
- `/src/websocket/socket_manager.cr` - Add jitter to cleanup, configurable limits
- New `/src/dtos/metrics_dto.cr` - Metrics response structure

**Frontend**:
- `/frontend/src/lib/websocket/connection.svelte.ts` - Add jitter, retry limits, polling fallback

**Testing**:
- New test files for WebSocket functionality
