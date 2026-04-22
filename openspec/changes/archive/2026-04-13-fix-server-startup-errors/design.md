## Context

Commit 274ee91c changed `src/quickheadlines.cr` to spawn the HTTP server (`ATH.run`) in a background fiber via `start_server_async(port)`. The intent was to prevent background refresh/clustering tasks from blocking HTTP server startup. However, `ATH.run` was moved into the spawn without any error handling — if it raises (port in use, binding failure, internal Athena error), the fiber dies silently and the main thread sleeps forever.

## Goals / Non-Goals

**Goals:**
- Restore reliable HTTP server binding to port 8080
- Restore process exit on port-in-use / binding errors (error visibility)
- Keep background refresh/clustering tasks out of the HTTP startup critical path

**Non-Goals:**
- Revert other stability improvements from 274ee91c (DB busy_timeout, HTTP client timeouts, etc.)
- Change Athena framework internals
- Modify background refresh or clustering logic

## Decisions

**Decision: Revert `ATH.run` to synchronous call on the main thread**

- `ATH.run` is designed to be the main blocking entry point for Athena applications. Running it in a spawned fiber is an antipattern that bypasses its built-in error handling and signal management.
- The stability goal (non-blocking background tasks) is already achieved by spawning `bootstrap.start_background_tasks` and `bootstrap.verify_feeds_loaded` — these were correctly moved out of the critical path.
- By calling `ATH.run` synchronously, binding errors (`Socket::Error` with `EADDRINUSE`) propagate to the top-level `rescue ex` block and cause `exit 1`.

**Decision: Keep background tasks spawned before `ATH.run`**

- `start_background_tasks` and `verify_feeds_loaded` are spawned before `ATH.run` blocks. This ensures they are running before the server accepts connections, so HTTP requests can be served immediately.
- The 500ms sleep before spawning background tasks (added in 274ee91c) is removed — it is unnecessary since the tasks are themselves spawned fibers and won't block.

**Decision: Inline handler construction**

- ClientIPHandler and WebSocketHandler are constructed in the main scope (not inside a spawned fiber). This is the same pattern that existed before 274ee91c.
- The `start_server_async` helper is removed entirely.

## Risks / Trade-offs

- **[Risk] Background tasks still run during `ATH.run`**: Because `ATH.run` blocks the main thread, any spawned fibers (refresh loop, clustering, cleanup) will interleave with HTTP handling. This was the case before 274ee91c and is acceptable — Crystal's cooperative scheduler ensures HTTP requests are handled promptly.
- **[Trade-off] No change to startup ordering**: Moving `ATH.run` back to synchronous means the first HTTP request may arrive before feeds are loaded (they load asynchronously via `start_feed_refresh`). This is the pre-274ee91c behavior and is already mitigated by the SPA's client-side loading state.
- **[Mitigation] Error visibility restored**: With synchronous `ATH.run`, port-in-use errors cause an immediate fatal log and exit, making the failure observable. The 274ee91c approach of spawning the server had no error handling, making silent failures impossible to debug.
