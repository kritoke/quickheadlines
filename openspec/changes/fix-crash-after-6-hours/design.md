## Context

The QuickHeadlines application experiences consistent crashes on FreeBSD in a jail environment after approximately 6 hours of operation. Investigation identified four distinct issues contributing to resource exhaustion:

1. **async_clustering fiber hang** - The completion fiber waits indefinitely for signals that may never come if spawned fibers fail
2. **LSH bands table growth** - Clustered items are protected from deletion but their LSH band entries continue to accumulate
3. **No graceful shutdown** - Database connections are never closed on termination
4. **Vug cache growth** - Module-level cache is never cleared after startup

## Goals / Non-Goals

**Goals:**
- Prevent indefinite fiber hangs in async_clustering
- Prevent unbounded LSH bands table growth
- Ensure database connections are properly closed on shutdown
- Prevent unbounded memory growth from cached data

**Non-Goals:**
- No changes to clustering algorithm behavior
- No changes to user-facing APIs or behavior
- No changes to database schema (add foreign key CASCADE instead)
- No breaking changes to existing functionality

## Decisions

### Decision 1: Timeout-based completion for async_clustering

**Choice:** Use `Channel.select` with `timeout` alternative instead of blocking `receive`

**Rationale:** The current code waits indefinitely for exactly `feeds.size` completions. If any fiber panics or fails before sending completion, the fiber hangs forever. Using `Channel.select` with a timeout allows the clustering to complete or timeout gracefully.

**Implementation:**
```crystal
spawn do
  timeout_time = 5.minutes from_now
  completed = 0
  feeds.size.times do
    select
    when completion_channel.receive?
      completed += 1
    when timeout(timeout_time)
      Log.warn { "async_clustering timed out after #{completed}/#{feeds.size} completions" }
      break
    end
  end
  StateStore.clustering = false
end
```

**Alternatives Considered:**
- Using a `CountDownLatch` - Not available in Crystal standard library
- Using a `WaitGroup` - Not idiomatic Crystal
- Monitoring with a separate fiber - Adds complexity

### Decision 2: CASCADE delete for LSH bands cleanup

**Choice:** Rely on existing `FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE` in schema and add explicit DELETE for orphaned bands

**Rationale:** The `lsh_bands` table already has a foreign key with CASCADE, but SQLite requires `PRAGMA foreign_keys = ON` to enforce it. Additionally, we should add explicit cleanup for any orphaned bands that may have accumulated.

**Implementation:**
```crystal
def cleanup_old_articles(retention_days : Int32)
  # ... existing DELETE for items ...
  
  # Clean up orphaned LSH bands (items that no longer exist)
  @db.exec("DELETE FROM lsh_bands WHERE item_id NOT IN (SELECT id FROM items)")
end
```

**Alternatives Considered:**
- Adding a trigger - SQLite triggers add complexity
- Changing schema - Breaking change, requires migration

### Decision 3: Graceful shutdown via at_exit

**Choice:** Add `at_exit` handler in `AppBootstrap` to call `DatabaseService.close`

**Rationale:** The `DatabaseService` already has a `close` method but it's never called. Adding `at_exit` ensures cleanup happens regardless of how the process terminates (normal exit, unhandled exception, or signals).

**Implementation:**
```crystal
# In AppBootstrap.initialize
at_exit do
  Log.info { "Shutting down gracefully..." }
  DatabaseService.instance.close rescue nil
end
```

**Alternatives Considered:**
- Signal handlers (SIGTERM, SIGINT) - Would require more complex fiber coordination
- `before_finalize` / `after_finalize` - Not available in Crystal
- Explicit shutdown API - Requires external process management

### Decision 4: Periodic Vug cache clearing

**Choice:** Clear Vug adapter cache during the existing 6-hour cleanup cycle

**Rationale:** The 6-hour cleanup scheduler already exists and runs periodic maintenance. Adding cache clearing here keeps all maintenance in one place and doesn't require a new scheduling mechanism.

**Implementation:**
In `start_cleanup_scheduler`:
```crystal
spawn do
  loop do
    sleep @cleanup_interval
    begin
      VugAdapter.clear_cache  # Add this line
      @feed_cache.cleanup_old_articles(...)
      # ... rest of cleanup
    rescue ex
      # ... error handling
    end
  end
end
```

## Risks / Trade-offs

[Risk: Timeout too short for large feed sets] → Mitigation: Use 5-minute timeout which should be sufficient for clustering even with many items; can be made configurable if needed

[Risk: CASCADE delete is slow on large datasets] → Mitigation: Already running during periodic cleanup which has built-in throttling; SQLite handles cascading deletes efficiently with proper indexes

[Risk: at_exit runs after other fibers may have crashed] → Mitigation: at_exit is the best effort in Crystal; crash during fiber execution may prevent clean exit but will at least log the error

[Risk: Vug cache clear causes temporary performance degradation] → Mitigation: Cache is cleared infrequently (every 6 hours) and only affects newly fetched items; re-extraction happens on-demand

## Open Questions

1. **Should we add a clustering timeout configuration option?** Currently hardcoded to 5 minutes. Consider adding to config structure.

2. **Should we add explicit memory logging?** Would help diagnose future memory issues before crashes occur.

3. **Should we add a database VACUUM after LSH band cleanup?** VACUUM is already called periodically in `save_feed_cache`. Consider adding after large deletions.
