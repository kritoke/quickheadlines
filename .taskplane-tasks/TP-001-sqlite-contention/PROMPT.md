# Task: TP-001 — Fix SQLite Database Contention & Locking

**Created:** 2026-04-30
**Size:** L

## Review Level: 1 (Plan Review)

**Assessment:** High blast radius — database layer touches feed fetching, clustering, cleanup, and API reads. Changes must preserve existing behavior while reducing lock contention.
**Score:** 7/8 — Blast radius: 2, Pattern novelty: 1, Security: 1, Reversibility: 1

## Canonical Task Folder

```
taskplane-tasks/TP-001-sqlite-contention/
├── PROMPT.md   ← This file (immutable above --- divider)
├── STATUS.md   ← Execution state (worker updates this)
├── .reviews/   ← Reviewer output (task-runner creates this)
└── .DONE       ← Created when complete
```

## Mission

Fix the SQLite "database is locked" errors that cause feed fetching and
clustering to fail after the application has been running for a few hours.
The single SQLite database is written to by 8 concurrent feed fetchers, up to
20 parallel clustering fibers, periodic VACUUM/cleanup operations, and API
reads from the web frontend. The current `busy_timeout=30s` and
`max_pool_size=3` are insufficient for this write-heavy concurrent load.

## Problem Analysis

### Evidence from logs (qh.log — 770 lines over ~30 minutes)

- **64 "database is locked" errors** from clustering fibers at 10:17:30Z
- **Shutdown failure**: "Error closing database: database is locked" at 10:28:10Z
- All clustering errors happen at the exact same timestamp (10:17:30.77-10:17:30.80)
  suggesting a thundering herd problem — all fibers hit the DB simultaneously

### Root Cause

1. **Single DB connection pool (size 3) shared by all writers**: Feed fetchers,
   clustering engine, cleanup jobs, and API reads all compete for 3 connections.

2. **No write serialization**: Multiple clustering fibers write simultaneously
   (`assign_clusters_bulk`, `store_lsh_bands`, etc.) with only a `Mutex` for
   coordination at the `FeedCache` level — but the mutex doesn't prevent SQLite
   internal contention.

3. **VACUUM during refresh**: `save_feed_cache` runs VACUUM hourly, which
   requires exclusive access. If a refresh is in progress, VACUUM fails with
   "database is locked" (already handled gracefully but indicates contention).

4. **WAL auto-checkpoint at 10MB**: The WAL can grow large between checkpoints,
   making checkpoint operations slow and blocking.

### Key Files & Current Behavior

| File | Role | Issue |
|------|------|-------|
| `src/constants.cr` | Defines `SQLITE_BUSY_TIMEOUT_MS=30000`, `DB_MAX_POOL_SIZE=3`, `MAX_PARALLEL_CLUSTERING=20` | Pool too small, too many parallel writers |
| `src/storage/database.cr` | `create_schema()` sets WAL mode, `busy_timeout`, `synchronous=NORMAL` | Good defaults but needs tuning |
| `src/storage/feed_cache.cr` | `FeedCache` wraps all DB ops with `@mutex` (Crystal Mutex) | Mutex helps but doesn't prevent SQLite-level contention |
| `src/services/database_service.cr` | Opens DB with `busy_timeout` and `max_pool_size` | Single pool for all operations |
| `src/storage/clustering_store.cr` | Clustering writes (LSH bands, cluster assignments) | 20 parallel fibers writing simultaneously |
| `src/storage/cleanup_store.cr` | VACUUM, WAL checkpoint, size-based cleanup | Exclusive operations conflict with writers |
| `src/fetcher/refresh_loop.cr` | `fetch_feeds_concurrently()` spawns 8 concurrent fetchers | Each fetcher does a DB upsert after fetching |
| `src/repositories/feed_repository.cr` | `upsert_with_items()` — the main write path for feed data | Called concurrently by all 8 fetchers |
| `src/services/clustering_engine.cr` | Background LSH clustering | Spawns up to 20 parallel fibers that all write |

## Dependencies

- **None** — This is the root-cause fix that unblocks TP-002 and TP-003.

## Context to Read First

- `src/constants.cr` — All SQLite-related constants
- `src/storage/database.cr` — Schema creation and DB initialization
- `src/storage/feed_cache.cr` — FeedCache class with mutex usage
- `src/services/database_service.cr` — DB connection pool setup
- `src/storage/clustering_store.cr` — Clustering write patterns
- `src/storage/cleanup_store.cr` — VACUUM and cleanup operations
- `src/repositories/feed_repository.cr` — Upsert logic
- `src/fetcher/refresh_loop.cr` — Concurrent fetch architecture

## Environment

- **Workspace:** Project root
- **Language:** Crystal (>= 1.18.0)
- **Database:** SQLite3 via crystal-sqlite3 + crystal-db
- **Services required:** None (tests use `just nix-build` for compilation check)

## File Scope

- `src/constants.cr` — Update DB constants
- `src/storage/database.cr` — PRAGMA tuning
- `src/storage/feed_cache.cr` — Mutex strategy changes
- `src/services/database_service.cr` — Connection pool tuning
- `src/storage/clustering_store.cr` — Serialize writes, batch operations
- `src/storage/cleanup_store.cr` — Ensure exclusive ops don't conflict

## Steps

### Step 0: Preflight

- [ ] Verify this PROMPT.md is readable
- [ ] Verify STATUS.md exists in the same folder
- [ ] Read all files listed in "Context to Read First"
- [ ] Understand the current DB write patterns and contention points

### Step 1: Increase Connection Pool & Tune SQLite PRAGMAs

- [ ] In `src/constants.cr`:
  - Increase `DB_MAX_POOL_SIZE` from 3 to a more appropriate value (e.g., 8-12)
  - Consider adding a `DB_BUSY_TIMEOUT_MS` that's sufficient (current 30s may be fine)
- [ ] In `src/storage/database.cr` `create_schema()`:
  - Review and potentially add `PRAGMA temp_store = MEMORY` (avoids temp table I/O)
  - Consider `PRAGMA page_size = 4096` if not already set
  - Verify WAL checkpoint settings are appropriate
- [ ] In `src/services/database_service.cr`:
  - Update the connection string to use the new pool size
  - Ensure `busy_timeout` is properly applied

### Step 2: Reduce Concurrent Clustering Writers

- [ ] In `src/storage/clustering_store.cr`:
  - Review the write paths: `store_lsh_bands`, `assign_clusters_bulk`, `assign_cluster`, `store_item_signature`
  - Batch writes where possible instead of per-item writes
  - Reduce the number of concurrent fibers writing at the same time — either:
    - Use a write queue/serializer pattern, OR
    - Reduce `MAX_PARALLEL_CLUSTERING` from 20 to a lower number (e.g., 4-8)
  - Ensure the Crystal `Mutex` is used consistently around multi-step write operations
- [ ] In `src/constants.cr`:
  - Consider reducing `MAX_PARALLEL_CLUSTERING` from 20 to a reasonable value

### Step 3: Separate Read and Write Concerns

- [ ] Review `src/repositories/feed_repository.cr`:
  - Ensure `upsert_with_items` uses a transaction to minimize lock duration
  - Check if individual INSERT statements can be batched
- [ ] Review `src/storage/feed_cache.cr`:
  - Verify the `@mutex` is protecting critical sections correctly
  - Consider if a reader-writer lock pattern would be better (multiple readers, single writer)

### Step 4: Verify VACUUM Doesn't Conflict With Active Operations

- [ ] In `src/storage/cleanup_store.cr`:
  - Ensure VACUUM and checkpoint operations check for active refreshes
  - The current graceful handling ("VACUUM skipped - database is locked") is good
  - Verify WAL auto-checkpoint threshold is appropriate
- [ ] In `src/storage/feed_cache.cr` `save_feed_cache()`:
  - Verify the hourly cleanup doesn't collide with feed refresh cycles

### Step 5: Compile & Verify

- [ ] Run `just nix-build` to verify the project compiles
- [ ] Fix any compilation errors
- [ ] Review all changes for correctness — no behavior changes except reduced contention

## Documentation Requirements

**Must Update:** None
**Check If Affected:** `OPERATING.md` if new tuning parameters are added

## Completion Criteria

- [ ] All "database is locked" error patterns are addressed:
  - Concurrent feed upserts no longer contend excessively
  - Clustering writes are serialized or batched appropriately
  - VACUUM/cleanup doesn't conflict with active operations
- [ ] `just nix-build` passes
- [ ] No behavior regressions — feeds still fetch, clustering still works, API still serves
