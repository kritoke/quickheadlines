# refresh-loop-resilience Specification

## Purpose
Ensures the feed refresh loop continues operating reliably over extended runtime by detecting and recovering from fiber crashes, semaphore exhaustion, and other silent failures.

## Background

After deploying the app, the refresh loop may stop fetching new items from feeds not long after initial deployment. Analysis reveals three bugs in `src/fetcher/refresh_loop.cr`:

### Bug 1 — `check_semaphore_health` leaks semaphore permits

```crystal
private def check_semaphore_health
  # ... drains available slots into `available` ...
  expected.times { CONCURRENCY_SEMAPHORE.send(nil) }  # ← always sends 8 back
end
```

If 3 of 8 slots are available, the function drains those 3 but **always sends 8 back**, growing the channel from 8 → 13. Over repeated health checks, the semaphore grows unboundedly, defeating the concurrency limit entirely.


### Bug 2 — `fetch_feeds_concurrently` orphans fibers on timeout

```crystal
when timeout(timeout_span)
  Log.warn { "fetch_feeds_concurrently: timed out after #{completed}/#{all_configs.size} feeds" }
  break  # ← exits receive loop, but spawned fibers keep running
end
```

The `break` exits the channel-receive loop, but spawned fibers for unfetched feeds are still running. Those fibers hold `CONCURRENCY_SEMAPHORE` permits and SQLite transaction locks. The `save_feed_cache` call that runs immediately after tries `vacuum`, which blocks waiting for those locks.


### Bug 3 — `refresh_all` blocks the loop indefinitely

Unlike the first run (which is spawned), subsequent `refresh_all` calls are synchronous. If a single feed hangs in `Fetcher.pull` past the 150s timeout, the **entire loop fiber is blocked**. The `StateStore.refreshing` flag is set `true` but never cleared to `false`, so subsequent cycles skip (`StateStore.refreshing? == true`).

## Requirements

### Requirement: Outer exception handler for refresh loop
The refresh loop fiber SHALL wrap the entire main loop in a `begin/rescue` block that catches any unhandled exception, logs the error with full backtrace, and restarts the loop after a 60-second delay.


#### Scenario: Unhandled exception in refresh cycle
- **WHEN** an exception escapes the inner exception handlers during a refresh cycle
- **THEN** the outer handler catches it, logs the error with backtrace, and restarts the loop after 60 seconds

#### Scenario: Repeated failures
- **WHEN** the refresh loop fails multiple times consecutively
- **THEN** each failure is logged and the loop continues attempting to restart

### Requirement: Semaphore health check sends back exactly what it drained

The `check_semaphore_health` function SHALL send back **exactly** the number of permits it drained from the channel — no more, no less.

```crystal
available.times { CONCURRENCY_SEMAPHORE.send(nil) }  # was: expected.times { ... }
```

If all 8 permits are available (none drained), zero sends are performed.

#### Scenario: Some slots leaked
- **WHEN** only 5 of 8 semaphore slots are available at health check
- **THEN** the function drains those 5 permits, logs a warning about 3 missing, and sends **exactly 5** permits back
- **AND** the semaphore returns to exactly 8 permits

#### Scenario: All slots healthy
- **WHEN** all 8 of 8 semaphore slots are available at health check
- **THEN** the function drains all 8, finds `available == expected`, logs nothing, and sends **exactly 8** permits back
- **AND** the semaphore remains at exactly 8 permits

#### Scenario: All slots blocked
- **WHEN** 0 of 8 semaphore slots are available at health check
- **THEN** the function drains 0 (hits timeout), logs a warning about 8 missing, and sends **exactly 0** permits back
- **AND** the semaphore remains at 0 permits (honest state — the previous code would have incorrectly reset it to 8)

### Requirement: `fetch_feeds_concurrently` waits for all spawned fibers to complete or timeout

The receive loop SHALL iterate **exactly** `all_configs.size` times to collect all feeds before the wall-clock timeout fires, rather than breaking on a per-iteration timeout.

The per-iteration timeout (`FEED_FETCH_TIMEOUT_SECONDS` seconds) is replaced by a **wall-clock timeout** that applies to the entire fetch batch. If a feed times out, its fiber still runs to completion (releasing its semaphore permit) but its result is simply not collected.

#### Scenario: Some feeds timeout
- **WHEN** 5 of 10 feeds complete within 150 seconds but 5 hang
- **THEN** the loop collects 5 results, then exits after 150s when all 10 iterations are done
- **AND** each hanging fiber completes and releases its semaphore permit via the `ensure` block
- **AND** no fibers are orphaned

#### Scenario: All feeds complete quickly
- **WHEN** all 10 feeds complete within 10 seconds
- **THEN** the loop collects all 10 results and exits in ~10 seconds
- **AND** no unnecessary waiting occurs

### Requirement: `refresh_all` runs with a hard outer timeout and never blocks the loop indefinitely

The refresh loop SHALL wrap the `refresh_all` call in a `begin`/`rescue`/`ensure` block with a `select`-based outer timeout so that a single stuck refresh cycle cannot block the loop forever.

A reasonable outer timeout is `refresh_minutes * 90` seconds (1.5× the configured refresh interval).

#### Scenario: Refresh hangs
- **WHEN** `refresh_all` is running and a fetch hangs the entire Crystal fiber
- **THEN** the outer 45-minute timeout (for 30-min refresh interval) fires, logs an error, and clears the `refreshing` flag
- **AND** the loop proceeds to the next cycle immediately

#### Scenario: Refresh completes normally
- **WHEN** `refresh_all` completes within the outer timeout
- **THEN** the result is processed normally and the loop continues

### Requirement: `StateStore.refreshing` is always reset after every refresh attempt

The `refreshing` flag SHALL be reset to `false` unconditionally after every `refresh_all` attempt, regardless of whether it succeeded, timed out, or raised an exception.


```crystal
begin
  refresh_all(active_config, cache, db_service)
rescue ex
  Log.error(exception: ex) { "refresh_all failed" }
ensure
  StateStore.refreshing = false
end
```

#### Scenario: Refresh succeeds
- **WHEN** `refresh_all` completes normally
- **THEN** `StateStore.refreshing` is set to `false` by the `ensure` block

#### Scenario: Refresh throws an exception
- **WHEN** `refresh_all` throws an exception
- **THEN** the exception is caught and logged
- **AND** `StateStore.refreshing` is set to `false` by the `ensure` block
- **AND** the loop continues

#### Scenario: Refresh times out
- **WHEN** the outer timeout fires before `refresh_all` completes
- **THEN** the timeout handler logs an error
- **AND** `StateStore.refreshing` is set to `false` by the `ensure` block
- **AND** the loop continues

### Requirement: Refresh loop heartbeat logging
The refresh loop SHALL log a periodic heartbeat message every 10 cycles to confirm the loop is still alive and operating normally.

#### Scenario: Heartbeat during normal operation
- **WHEN** the refresh loop completes 10 cycles without errors
- **THEN** a debug-level log message is emitted confirming loop health and cycle count

#### Scenario: Heartbeat after recovery
- **WHEN** the refresh loop restarts after an exception
- **THEN** the cycle counter resets and heartbeat logging resumes from zero

## Design

### `check_semaphore_health` fix (`src/fetcher/refresh_loop.cr`)

```crystal
# Before:
expected.times { CONCURRENCY_SEMAPHORE.send(nil) }

# After:
# Only send back exactly what was drained — not the full `expected` count.
available.times { CONCURRENCY_SEMAPHORE.send(nil) }
```

### `fetch_feeds_concurrently` fix

```crystal
fetch_start = Time.monotonic
all_configs.size.times do
  Fiber.yield
  select
  when data = channel.receive?
    if data
      fetched_map[data.url] = data
    elsif config.debug?
      Log.for("quickheadlines.feed").warn { "refresh_all: failed to fetch feed" }
    end
    completed += 1
  when timeout(1.millisecond)
    # No feed ready yet; yield to allow other fibers to complete.
  end

  # Wall-clock timeout check after each iteration.  This replaces the
  # per-iteration timeout+break that was orphaning fibers.
  elapsed = Time.monotonic - fetch_start
  if elapsed > timeout_span
    Log.for("quickheadlines.feed").warn { "fetch_feeds_concurrently: timed out after #{completed}/#{all_configs.size} feeds" }
    break
  end
end
```

### Outer timeout and `ensure` for `StateStore.refreshing`

```crystal
begin
  refresh_all(active_config, cache, db_service)
  if active_config.debug?
    Log.for("quickheadlines.feed").debug { "Refreshed feeds" }
  end
rescue ex
  Log.for("quickheadlines.feed").error(exception: ex) { "refresh_loop refresh_all failed" }
ensure
  # Always reset the refreshing flag — even on exception or timeout.
  # This prevents the loop from being permanently stuck.
  StateStore.refreshing = false
end

# Outer timeout guard: if refresh_all blocks past 1.5× the refresh interval,
outer_timeout = (active_config.refresh_minutes * SECONDS_PER_MINUTE * 3 // 2).seconds
sleep_duration = (active_config.refresh_minutes * SECONDS_PER_MINUTE).seconds
select
when timeout(sleep_duration)
  # Normal sleep completed
when timeout(outer_timeout)
  Log.error { "refresh_all timed out after #{outer_timeout.total_seconds.round}s" }
end
```


## Verification

### Runtime verification

1. Start the app with `debug: true` in `feeds.yml`
2. Kill one of the feed URLs temporarily (e.g., via firewall rule)
3. Wait for 3+ refresh cycles (~90 minutes with 30-minute interval)
4. Verify the loop continues operating (new items appear from healthy feeds)
5. Check that no semaphore channel grows beyond 8 items: log output shows "only X/8 slots available"

### Ameba compliance

`nix develop . --command ameba src/fetcher/refresh_loop.cr` should report only the pre-existing CyclomaticComplexity warning and SharedVarInFiber warning (both pre-existing, not introduced by this change).
