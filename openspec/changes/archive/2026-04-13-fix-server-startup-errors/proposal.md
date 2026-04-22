## Why

Commit 274ee91c ("fix: FreeBSD crash stability and server startup") moved `ATH.run` into a spawned fiber to prevent background tasks from blocking HTTP server startup. However, this broke server binding: when `ATH.run` runs in a spawned fiber without error handling, startup failures (port already in use, binding errors) kill the fiber silently, leaving the main thread sleeping forever — the app appears to run but does not serve port 8080 and does not exit when the port is occupied.

## What Changes

1. **Revert server startup to synchronous `ATH.run`** — Remove `start_server_async` helper and call `ATH.run` directly on the main thread (restoring pre-274ee91c behavior for server binding).
2. **Keep background tasks spawned** — `bootstrap.start_background_tasks` and `bootstrap.verify_feeds_loaded` remain spawned so refresh/clustering work does not block HTTP handling.
3. **Restore error handling** — Because `ATH.run` is synchronous, binding errors (e.g., `EADDRINUSE`) propagate to the top-level `rescue ex` block and the process exits with code 1 as expected.
4. **Inline handler setup** — WebSocket and ClientIP handlers are built in the main scope (same as before the stability commit), not passed through a spawned fiber.

## Capabilities

### New Capabilities
- `server-startup-error-handling`: Ensure `ATH.run` errors (port in use, binding failure, unhandled exception) are caught by the top-level rescue and cause the process to exit with a fatal log message.

### Modified Capabilities
- None — no spec-level behavior change; this is a bug-fix restoring correct runtime behavior.

## Impact

- **Affected file**: `src/quickheadlines.cr` — reverts the server startup section to inline synchronous `ATH.run`.
- **Preserved from 274ee91c**: `bootstrap.start_background_tasks` and `bootstrap.verify_feeds_loaded` remain spawned; they were correctly moved out of the critical path.
- **Side effect**: Background refresh/clustering tasks may briefly block during init (before the fix is confirmed working). The 500ms sleep before spawning background tasks is removed since background tasks are now spawned before `ATH.run` blocks the main thread.
