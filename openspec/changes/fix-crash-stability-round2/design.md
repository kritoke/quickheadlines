## Context

The QuickHeadlines application crashes on FreeBSD in a jail after ~6 hours. Round 1 fixes addressed clustering hangs, LSH cleanup, graceful shutdown, and Vug cache. Deep analysis revealed additional critical issues: SQLite SQLITE_BUSY errors from concurrent writes with zero tolerance, HTTP::Client file descriptor leaks, and feed fetch deadlock potential.

## Goals / Non-Goals

**Goals:**
- Prevent SQLITE_BUSY crashes by adding busy_timeout to SQLite connections
- Prevent FD exhaustion from leaked HTTP::Client connections
- Prevent feed fetch deadlock from unhandled fiber failures
- Improve FreeBSD/ZFS compatibility with mmap_size=0
- Prevent unbounded DB connection pool growth

**Non-Goals:**
- No changes to clustering algorithm
- No changes to user-facing behavior
- No architectural refactoring of repository layer mutex usage (deferred)

## Decisions

### Decision 1: busy_timeout via URI parameter vs PRAGMA

**Choice:** Use URI parameter `?busy_timeout=5000` in connection string

**Rationale:** The `crystal-sqlite3` shard supports `busy_timeout` as a URI parameter (parsed in `connection.cr`). This is cleaner than a separate `db.exec("PRAGMA busy_timeout = 5000")` call and ensures it's set before any operations.

### Decision 2: mmap_size=0 for FreeBSD

**Choice:** Set `PRAGMA mmap_size = 0` unconditionally

**Rationale:** While this primarily helps FreeBSD/ZFS, it also prevents double-caching on Linux. The performance impact is minimal for this workload (small database, mostly reads). Safer to disable globally.

### Decision 3: max_pool_size=5

**Choice:** Set `max_pool_size=5` in connection string

**Rationale:** With 64MB cache per connection, 5 connections = 320MB max for SQLite cache. This is reasonable for a jail environment. The actual concurrency during feed refresh is bounded by CONCURRENCY_SEMAPHORE (8), but most of those are network I/O, not DB writes. 5 connections provides headroom without excessive memory use.

### Decision 4: HTTP::Client close in ensure blocks

**Choice:** Wrap HTTP::Client usage in begin/ensure blocks

**Rationale:** Crystal's GC will eventually close sockets via finalizers, but on FreeBSD with Boehm GC this is unreliable. Explicit close in ensure guarantees cleanup even on exceptions.

### Decision 5: Feed fetch timeout via select

**Choice:** Use `select` with timeout on `channel.receive` in `fetch_feeds_concurrently`

**Rationale:** If any spawned fiber fails before sending to the channel, the main fiber blocks forever. Adding a timeout prevents this deadlock.

## Risks / Trade-offs

[Risk: busy_timeout=5000ms may mask real lock contention] → Mitigation: 5 seconds is reasonable; logged warnings already exist for slow refreshes

[Risk: max_pool_size=5 may cause checkout timeouts under heavy load] → Mitigation: DB pool has retry logic; checkout_timeout defaults to 5s

[Risk: HTTP::Client close in ensure may mask underlying connection issues] → Mitigation: Errors from close are caught silently; the original error is still raised
