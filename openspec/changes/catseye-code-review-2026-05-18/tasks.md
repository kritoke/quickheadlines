Tasks

This file lists the actionable tasks derived from the 2026-05-18 Catseye scan. Each task should be created as a separate OpenSpec change when work begins.

## P0 — Correctness & Safety

- [x] 1.1 Fix DeadLetter in database_service.cr:40
  - Channel `@db` closed before receive — sender gets ClosedError
  - **Done:** Added `begin/rescue DB::Error | IO::Error` around `@db.close` to handle already-closed connections gracefully

- [x] 1.2 Fix MutedPack in event_broadcaster.cr:59
  - SHUTDOWN_CHANNEL send with no consumer — shutdown signals lost
  - **Done:** Added `select` with timeout + `rescue Channel::ClosedError` to handle cases where broadcaster loop already exited

- [x] 1.3 Fix PathTraversal in config/loader.cr:4
  - `File.read(path)` with variable argument
  - **Done:** Added `File.expand_path` + `File.file?` validation before `File.read`, with early return error on missing file

## P1 — Reliability

- [x] 2.1 Add error handling to OrphanedSpawn fibers
  - **Analysis:** Only 1 of 17 flagged spawns genuinely lacked error handling (the rest already had `begin/rescue`)
  - **Done:** Fixed `refresh_loop.cr:445` sleep timer fiber — added `begin/rescue` wrapper
  - **Note:** Updated false positives doc — 16/17 OrphanedSpawn findings are false positives

## P2 — Maintainability (Refactor Backlog)

- [ ] 3.1 Refactor `start_refresh_loop` in refresh_loop.cr:308
  - Current: 774 AST nodes, complexity 32, nesting depth 23
  - Target: Break into `init_loop`, `fetch_cycle`, `health_check_cycle`, `shutdown_cycle`
  - Estimate: 1-2 days

- [ ] 3.2 Split `FeedFetcher` God Object
  - Current: 30 methods
  - Target: CacheHandler, FetchExecutor, FaviconResolver, EntryParser
  - Estimate: 2-3 days

- [ ] 3.3 Fix DRY violation in story_dto.cr
  - Current: 34 duplicate blocks
  - Target: Crystal macro or shared builder method
  - Estimate: 1 day

- [ ] 3.4 Extract parameter objects for long parameter lists
  - `categorize_backfill` (8 params) → `BackfillContext` struct
  - `apply_favicon_updates` (7 params) → `FaviconUpdateBatch` struct
  - `process_feed_favicon` (7 params) → `FaviconProcessContext` struct
  - `assign_cluster_item` (7 params) → `ClusterAssignment` struct
  - Estimate: 1 day

- [ ] 3.5 Extract DataClump parameter groups into structs
  - `bands + threshold` → `LshConfig` struct
  - `limit + offset` → `PaginationParams` struct
  - `max_requests + window_seconds` → `RateLimitConfig` struct
  - `config + db_service` → `ServiceDeps` struct
  - `item_limit + software_config` → `FetcherConfig` struct
  - `db + mutex` → `StoreDeps` struct
  - Estimate: 1 day

## Notes

- DeadCode findings (19 instances) are false positives from Athena framework macros — see false positives doc
- MagicNumber findings (68) are predominantly HTTP status codes — self-explanatory, no action needed
- LargeClass findings (~60) are scanner bugs with Crystal modules — inflated line counts
- False positives: documented in `planning/catseye-false-positives-2026-05-18.md`
