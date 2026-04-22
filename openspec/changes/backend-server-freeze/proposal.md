## Why

The Crystal backend server freezes after ~30-60 seconds of runtime, becoming unresponsive to HTTP requests while the process remains alive. The issue reproduces on the original code (pre-cleanup) and is caused by the single-threaded Athena HTTP server getting overwhelmed by concurrent blocking operations: feed refresh (8 concurrent HTTP fibers), favicon sync (blocking HTTP + DB writes), DB writes from multiple fibers, and incoming HTTP requests -- all competing on one thread.

## What Changes

- Add in-memory favicon caching to eliminate repeated disk I/O for `/favicons/{hash}.{ext}` endpoint
- Add `Cache-Control` headers to favicon and proxy-image responses (already done, keep)
- Move favicon sync to yield more frequently during blocking operations
- Add connection backlog increase and potentially `reuse_port` for better connection handling
- Investigate and fix the root cause of the event loop blocking

## Capabilities

### New Capabilities
- `backend-performance`: Server stability and performance under load

### Modified Capabilities

## Impact

- `src/controllers/proxy_controller.cr` - favicon caching
- `src/favicon_storage.cr` - in-memory cache layer
- `src/quickheadlines.cr` - server configuration
- `src/services/favicon_sync_service.cr` - yield during blocking ops
