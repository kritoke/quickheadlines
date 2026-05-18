Design notes

This change is primarily a tracking/coordination change. The goal is to triage the Catseye scan findings, document false positives, and create actionable tasks for genuine issues.

No direct code changes will be made in this change. Implementation changes will be made as separate OpenSpec changes created from tasks in tasks.md.

## Refactoring Priorities

### P0 — Correctness & Safety

1. **DeadLetter in database_service.cr** — Channel closed before receive causes ClosedError on shutdown. Needs graceful channel drain or sentinel value pattern.
2. **MutedPack in event_broadcaster.cr** — SHUTDOWN_CHANNEL send with no consumer means shutdown signals are lost. Needs a receive loop or direct call pattern.
3. **PathTraversal in config/loader.cr** — `File.read(path)` needs path validation/whitelist.

### P1 — Reliability

4. **OrphanedSpawn (17 instances)** — Every spawned fiber needs `begin/rescue Log.error` to prevent silent deaths. Files:
   - `src/controllers/admin_controller.cr` (2 spawns)
   - `src/controllers/timeline_controller.cr` (1 spawn)
   - `src/fetcher/refresh_loop.cr` (3 spawns)
   - `src/quickheadlines.cr` (1 spawn)
   - `src/rate_limiter.cr` (1 spawn)
   - `src/services/app_bootstrap.cr` (6 spawns)
   - `src/websocket/event_broadcaster.cr` (1 spawn)
   - `src/websocket/socket_manager.cr` (1 spawn)

### P2 — Maintainability

5. **start_refresh_loop refactoring** — Break 774-node, complexity-32, nesting-23 function into: `init_loop`, `fetch_cycle`, `health_check_cycle`, `shutdown_cycle`.
6. **FeedFetcher God Object** — 30 methods. Split into: CacheHandler, FetchExecutor, FaviconResolver, EntryParser.
7. **story_dto.cr DRY** — 34 duplicate blocks. Use Crystal macros or shared builder methods.
8. **Parameter objects** — Extract structs for: `categorize_backfill` (8 params), `apply_favicon_updates` (7 params), `process_feed_favicon` (7 params).

## Acceptance Criteria

- All real issues have tasks in tasks.md
- All false positives are documented in planning/catseye-false-positives-2026-05-18.md
- No code changes in this change — purely tracking/triage
