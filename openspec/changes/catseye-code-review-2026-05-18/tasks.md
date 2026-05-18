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

- [x] 3.3 Fix DRY violation in story_dto.cr
  - Current: 34 duplicate blocks
  - **Done:** Extracted `build()` private helper method; `from_entity` and `from_cluster_item` now delegate to it

- [x] 3.4 Extract parameter objects for long parameter lists
  - **Done:** `favicon_sync_service.cr` — extracted `FeedFaviconRow`, `FaviconUpdateResult`, `BackfillLists` structs
    - `process_feed_favicon` now takes `FeedFaviconRow` instead of 7 params
    - `apply_favicon_updates` now takes `FaviconUpdateResult` instead of 7 params
    - `categorize_backfill` now takes `FeedFaviconRow` + `BackfillLists` instead of 8 params
    - `load_feeds_data` returns `Array(FeedFaviconRow)` instead of raw tuples
  - **Done:** `clustering_service.cr` — extracted `ClusterMatchResult` struct
    - `best_cluster_match` returns `ClusterMatchResult` instead of `Tuple`
    - `assign_cluster_item` takes `ClusterMatchResult` (6 params → 5)

- [x] 3.5 Extract DataClump parameter groups into structs
  - **Skipped:** After analysis, each pair appears in only 3-4 call sites across different layers.
  - Adding structs for `bands+threshold` (3 sites), `limit+offset` (4 sites), `max_requests+window_seconds` (3 sites)
    would add indirection without meaningful benefit. These are simple value pairs, not entangled state.
  - **Decision:** Accept as-is. Not worth the added complexity.

## Notes

- DeadCode findings (19 instances) are false positives from Athena framework macros — see false positives doc
- MagicNumber findings (68) are predominantly HTTP status codes — self-explanatory, no action needed
- LargeClass findings (~60) are scanner bugs with Crystal modules — inflated line counts
- False positives: documented in `planning/catseye-false-positives-2026-05-18.md`
