## Context

QuickHeadlines is a Crystal/Svelte RSS reader with WebSocket real-time updates and MinHash/LSH clustering. A recent code review identified critical bugs that can cause production outages (IP count leak blocking legitimate users) and silent data loss (article deduplication by title instead of link).

### Current State Issues

1. **WebSocket SocketManager** uses a dual-track cleanup: `cleanup_dead_connections` manually removes connections but never decrements IP counts. The `unregister_connection` helper that does proper cleanup is only called from `writer_fiber` on normal disconnect.

2. **StateStore clustering flag** is protected by two different mutexes - `@@mutex` for reads (`clustering?`) and `@@clustering_mutex` for writes (`clustering=`, `start_clustering_if_idle`). `refresh_all` sets it via `StateStore.update` which uses `@@mutex`. Result: race condition allowing duplicate clustering runs.

3. **CLUSTERING_JOBS Atomic counter** is set to feed count, then decremented in fiber `ensure` blocks. If a fiber crashes before the `ensure` runs, the counter stays elevated and `clustering` never returns to false.

4. **FeedRepository.insert_items** deduplicates by title. RSS feeds frequently have multiple items with identical titles but different links (especially for "Security Update" or error-type feeds). Legitimate articles are silently dropped.

5. **WebSocket handler** accepts connections from any Origin header, enabling cross-site WebSocket hijacking.

6. **RateLimiter.get_or_create** checks `@@instances[key]?` then assigns without locking, allowing concurrent requests to create duplicate instances.

7. **StateStore.updated_at** is set with `Time.local` in some places and `Time.utc` in others, creating timezone-dependent comparison bugs.

## Goals / Non-Goals

**Goals:**
- Fix all 3 critical and 5 high-severity bugs identified in code review
- Ensure clustering subsystem is crash-safe and uses consistent locking
- Prevent silent data loss in feed item storage
- Add basic WebSocket security (Origin validation)

**Non-Goals:**
- No API changes - all fixes are internal
- No dependency changes or Crystal version bumps
- Not implementing new features - only fixing bugs
- Not adding extensive test coverage (follows existing patterns)

## Decisions

### Decision 1: Fix cleanup_dead_connections IP leak
**Choice:** Call `unregister_connection(conn)` instead of manual removal
**Rationale:** `unregister_connection` already handles IP decrement + activity cleanup + logging. Reimplementing this logic in `cleanup_dead_connections` caused the bug. The method was private but only called from one place - the writer fiber - which was the intended cleanup path.
**Alternatives:** Could have added `decrement_ip_count` to cleanup_dead_connections directly, but that would duplicate logic.

### Decision 2: Unify clustering mutex
**Choice:** Route all clustering flag access through `@@mutex` via `StateStore.update`
**Rationale:** `@@mutex` is the general-purpose state mutex already used for all other StateStore operations. Creating a separate `@@clustering_mutex` was a mistake - it should have used the general mutex. `start_clustering_if_idle` should return a new state snapshot that the caller applies via `StateStore.update`.
**Alternatives:** Could make `clustering?` use `@@clustering_mutex`, but that means read-side also needs clustering mutex. Cleaner to use single mutex.

### Decision 3: Replace CLUSTERING_JOBS counter with Channel-based tracking
**Choice:** Use a `Channel(Nil)` with one token per feed, collect completions
**Rationale:** More reliable than Atomic counter that can be corrupted on exceptions. Crystal fibers don't have try/finally semantics that guarantee the ensure block runs - if a fiber is killed by the scheduler mid-execution, ensure may not run. Channel-based approach is explicit: parent spawns N fibers, parent receives N completions.
**Alternatives:** Could wrap fiber body in extra begin/rescue/ensure, but channel approach is cleaner and more explicit.

### Decision 4: Remove title-based deduplication
**Choice:** Remove `existing_titles` set and title comparison. Use `INSERT OR IGNORE` which respects `UNIQUE(feed_id, link)` constraint.
**Rationale:** The DB already has `UNIQUE(feed_id, link)` constraint and `INSERT OR IGNORE` handles link-based dedup at the DB level. Title-based dedup was a mistaken attempt to prevent duplicates that actually causes data loss.
**Alternatives:** Could keep title dedup as an additional check alongside link dedup, but it's unnecessary complexity.

### Decision 5: Add WebSocket Origin validation
**Choice:** Check Origin header against Host header on WebSocket upgrade
**Rationale:** Standard CSRF protection for WebSocket. Compare Origin against allowed hosts. Reject connections where Origin doesn't match.
**Alternatives:** Could use CORS preflight, but WebSocket doesn't support preflight. Could require authentication token in WebSocket URL, but that's less standard.

### Decision 6: Thread-safe RateLimiter instantiation
**Choice:** Use `@@cleanup_lock.synchronize` for instance creation, not just cleanup
**Rationale:** The instance hash was being read and written concurrently without protection. The `@@cleanup_lock` mutex already exists and is used for cleanup, extend it to creation.
**Alternatives:** Could use `Concurrent::Hash` from Crystal's concurrent library, but it may not be available. Mutex is simpler.

### Decision 7: Consistent Time.utc for state
**Choice:** Replace all `Time.local` with `Time.utc` for state timestamps
**Rationale:** `Time.local` depends on server timezone. If server timezone changes, state comparisons break. `Time.utc` is deterministic. The refresh loop compares `File.info.modification_time` (local time) against `last_mtime` which would be local if set with `Time.local`. Using UTC everywhere is simpler.
**Alternatives:** Could use `Time.utc` for new values and convert on display, but since all internal comparisons use UTC, just use UTC everywhere.

### Decision 8: Remove redundant janitor
**Choice:** Remove `start_janitor` and let `start_ws_janitor` handle all connection cleanup
**Rationale:** Both janitors call `cleanup_dead_connections`. The 60-second one has no stats logging; the 5-minute one does. Having two just doubles cleanup work and the 60-second one is less thorough.
**Alternatives:** Could make them share work, but simpler to consolidate.

### Decision 9: Fix frontend WebSocket listener cleanup
**Choice:** Add `websocketConnection.removeEventListener(handleWebSocketMessage)` to `$effect` cleanup return
**Rationale:** Without removal, every `$effect` re-run (on tab change, etc.) adds a new listener. Old listeners remain but their component is gone, creating memory leaks.
**Alternatives:** Could use a module-level listener registry, but this fix is simpler for the immediate issue.

## Risks / Trade-offs

- [Risk] Channel-based clustering completion changes fiber flow → Mitigation: Well-tested pattern in Crystal, similar to `Channel#receive` waiting
- [Risk] Removing title dedup may insert more items than before → Mitigation: `INSERT OR IGNORE` with unique constraint still prevents true duplicates; more items is better than silent data loss
- [Risk] Origin validation may reject legitimate proxies → Mitigation: Only validate when Origin is present; allow direct connections without Origin header

## Migration Plan

1. Apply changes file-by-file following the tasks list
2. Run `just nix-build` to verify compilation
3. Run `nix develop . --command crystal spec` for backend tests
4. Run `cd frontend && npm run test` for frontend tests
5. Deploy - no migration needed (all internal state, no schema changes)
