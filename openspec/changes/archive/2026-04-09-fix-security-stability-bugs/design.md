## Context

Security vulnerabilities and stability issues were discovered during code review. The codebase uses Crystal 1.18.2 with Athena framework, SQLite for storage, and Svelte 5 frontend. These bugs affect:

1. **SQL injection via LIKE queries** - `clustering_store.cr:24-38`
2. **Nil dereference in clustering** - `refresh_loop.cr:164-173`
3. **Silent transaction failures** - `clustering_store.cr:108-125`
4. **Time source mixing** - `refresh_loop.cr:232-234`
5. **Unbounded LSH candidates** - `clustering_store.cr:84-98`
6. **Overly broad error catching** - `socket_manager.cr:230`
7. **Cache counter overflow** - `color_extractor.cr:105,132`

## Goals / Non-Goals

**Goals:**
- Fix SQL injection vulnerability in `find_by_keywords`
- Add nil safety to `process_feed_item_clustering`
- Make transaction failures explicit (raise instead of silent continue)
- Use consistent time sources
- Bound LSH candidate set size
- Distinguish socket errors properly
- Fix cache counter overflow

**Non-Goals:**
- No API changes
- No database schema changes
- No changes to external behavior (only internal correctness)
- No performance optimizations (beyond safety bounds)

## Decisions

### 1. SQL LIKE Escaping

**Decision:** Create a dedicated `escape_sql_like` function that escapes ALL special SQL characters, not just `\`, `%`, `_`.

**Rationale:** The current `escape_like_pattern` only handles `\`, `%`, `_` but SQL LIKE has additional metacharacters. Using parameterized queries with proper escaping is the defense-in-depth approach.

**Alternatives:**
- Use `LIKE ?` with escaped parameter (chosen - simpler, no new dependencies)
- Use `ESCAPE` clause (more complex, same result)

### 2. Nil Safety in Clustering

**Decision:** Add early return when `feed_id` is nil in `process_feed_item_clustering`.

**Rationale:** If a feed is not yet in the database (fresh deployment), attempting to use `nil` as `feed_id` would cause issues downstream. The fix is a simple guard clause.

### 3. Transaction Error Propagation

**Decision:** Re-raise exceptions from `assign_clusters_bulk` instead of swallowing them.

**Rationale:** Silent failures in clustering lead to inconsistent state. Callers need to know if clustering assignments failed.

**Alternatives:**
- Return a result struct (breaking change to API)
- Raise exception (chosen - simpler, existing pattern)

### 4. Time Source Consistency

**Decision:** Use `Time.utc` for both measurement and comparison in refresh loop.

**Rationale:** `Time.monotonic` is for measuring elapsed time, but the alert threshold compares against wall-clock duration. Mixing can cause false positives after suspend/resume or NTP sync.

**Alternatives:**
- Use only `Time.utc` for both (chosen - consistent)
- Use only monotonic time (requires more refactoring)

### 5. LSH Candidate Bounds

**Decision:** Add a `MAX_LSH_CANDIDATES` constant (500) and enforce it in `find_lsh_candidates`.

**Rationale:** Without bounds, malicious content could cause unbounded memory growth.

### 6. Socket Error Handling

**Decision:** Distinguish `EOFError` (normal close) from other `IO::Error` in `cleanup_dead_connections`.

**Rationale:** `EOFError` means the connection was closed cleanly - not a dead connection. Catching it as dead leads to false positives.

### 7. Cache Counter Overflow

**Decision:** Use `Time.utc.to_unix_ms` instead of incrementing counter for LRU access ordering.

**Rationale:** No overflow risk, sufficient granularity for LRU ordering.

## Risks / Trade-offs

[Risk: Breaking changes to error handling] → Transaction failures now raise instead of silently continue. Callers may need to handle exceptions. Mitigation: This is a bug fix - callers shouldn't be relying on silent failures.

[Risk: Bounded LSH candidates may miss valid duplicates] → Mitigation: 500 candidates is sufficient for realistic feeds. The LSH threshold of 0.35 already limits candidates significantly.

## Open Questions

None - all issues are well-understood bugs with clear fixes.
