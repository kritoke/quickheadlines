# Task: TP-002 — Harden Feed Fetch Against Hangs & Semaphore Exhaustion

**Created:** 2026-04-30
**Size:** M

## Review Level: 1 (Plan Review)

**Assessment:** Medium blast radius — changes the feed fetching pipeline but the core logic is straightforward timeout/concurrency tuning.
**Score:** 4/8 — Blast radius: 1, Pattern novelty: 1, Security: 0, Reversibility: 1

## Canonical Task Folder

```
taskplane-tasks/TP-002-fetch-timeout-hardening/
├── PROMPT.md   ← This file (immutable above --- divider)
├── STATUS.md   ← Worker updates this
├── .reviews/   ← Reviewer output
└── .DONE       ← Created when complete
```

## Mission

Prevent feed fetching from hanging and exhausting the concurrency semaphore,
which blocks subsequent refresh cycles. Currently, a single slow/hung feed
(DNS timeout to a dead domain, slow server response) can hold a concurrency
slot for up to 5 minutes (`FEED_FETCH_TIMEOUT_SECONDS=300`), cascading into
missed refresh cycles and stale data.

## Problem Analysis

### Evidence from logs

- `server_debug.log` shows DNS resolution failures for dead domains
  (e.g., `feeds.businessinsider.com`) that block the fetch fiber
- `qh.log` shows "Read timed out" errors on feed extraction
  (e.g., `engadget.com`)
- Multiple feeds return 403/404 errors after the initial successful fetch period
- The `CONCURRENCY_SEMAPHORE` (8 slots) can be fully consumed by hung feeds,
  blocking the entire refresh cycle

### Current Architecture

```
refresh_all()
  └── fetch_feeds_concurrently()     ← spawns 1 fiber per feed (207 feeds)
       └── CONCURRENCY_SEMAPHORE     ← limits to 8 concurrent
            └── FeedFetcher.fetch()  ← per-feed: retry loop with exponential backoff
                 └── Fetcher.pull()  ← HTTP fetch (can hang on DNS/connect/read)
```

### Key Constants (src/constants.cr)

```
CONCURRENCY               =   8     # concurrent fetchers
HTTP_CONNECT_TIMEOUT      =  10     # seconds
HTTP_READ_TIMEOUT         =  30     # seconds
FETCH_TIMEOUT_SECONDS     =  60     # total per-feed wall-clock timeout
MAX_RETRIES               =   3     # retries with exponential backoff
MAX_BACKOFF_SECONDS       =  60     # max backoff between retries
FEED_FETCH_TIMEOUT_SECONDS = 300   # timeout for the ENTIRE batch fetch
```

### Problems

1. **No DNS/connect timeout isolation**: `Fetcher.pull()` can hang on DNS
   resolution for dead domains well beyond `HTTP_CONNECT_TIMEOUT` if the
   underlying socket doesn't respect the timeout.

2. **Retry backoff compounds with timeout**: A feed that times out 3 times
   with exponential backoff (2s + 4s + 8s = 14s backoff) plus 3x 60s timeout
   = 194 seconds holding a semaphore slot.

3. **VugAdapter favicon fetch can hang**: `VugAdapter.get_favicon()` is called
   during `handle_success()` and can also hang on DNS resolution. The
   `safe_get_favicon_with_fallback` catches `IO::TimeoutError` and
   `Socket::Addrinfo::Error` but may not catch all hang scenarios.

4. **`FEED_FETCH_TIMEOUT_SECONDS=300` is too generous**: The overall batch
   timeout of 5 minutes means a single bad cycle can delay the next refresh.

5. **No per-feed wall-clock limit**: While `should_abort_fetch?` checks elapsed
   time, it only checks at the top of the retry loop — if `Fetcher.pull()` itself
   blocks for minutes, the abort check never runs.

## Dependencies

- **Depends on: TP-001** — DB contention must be resolved first so that fetch
  failures are genuinely network/timeout issues, not DB lock issues.

## Context to Read First

- `src/constants.cr` — All fetch-related constants
- `src/fetcher/refresh_loop.cr` — Concurrent fetch architecture and semaphore
- `src/fetcher/feed_fetcher.cr` — Per-feed fetch logic with retry/backoff
- `src/fetcher/vug_adapter.cr` — Favicon fetching (potential hang source)

## Environment

- **Workspace:** Project root
- **Language:** Crystal (>= 1.18.0)
- **Services required:** None

## File Scope

- `src/constants.cr` — Timeout constants
- `src/fetcher/refresh_loop.cr` — Batch fetch timeout
- `src/fetcher/feed_fetcher.cr` — Per-feed timeout and retry logic
- `src/fetcher/vug_adapter.cr` — Favicon fetch timeout (if needed)

## Steps

### Step 0: Preflight

- [ ] Verify this PROMPT.md is readable
- [ ] Verify STATUS.md exists in the same folder
- [ ] Read all files listed in "Context to Read First"

### Step 1: Reduce Per-Feed Wall-Clock Timeout

- [ ] In `src/constants.cr`:
  - Consider reducing `FETCH_TIMEOUT_SECONDS` from 60 to something more reasonable (e.g., 30-45s)
  - This is the maximum time a single feed fetch attempt should take
- [ ] In `src/fetcher/feed_fetcher.cr`:
  - Ensure `should_abort_fetch?` is the authoritative wall-clock limit
  - The retry loop's total time (attempts × timeout + backoff) should not
    exceed `FETCH_TIMEOUT_SECONDS` for the entire operation

### Step 2: Reduce Overall Batch Fetch Timeout

- [ ] In `src/constants.cr`:
  - Consider reducing `FEED_FETCH_TIMEOUT_SECONDS` from 300 to something
    more reasonable (e.g., 120-180s) — this is the timeout for the entire
    batch of 207 feeds
  - With 8 concurrent slots and ~30s per feed, 207 feeds should complete
    in ~13 minutes worst case, but a single cycle shouldn't take 5 minutes
    of wall time just for the Channel select

### Step 3: Add Per-Feed Timeout Enforcement

- [ ] In `src/fetcher/feed_fetcher.cr` `fetch()` method:
  - Wrap the entire retry loop in a `select` with a timeout equal to
    `FETCH_TIMEOUT_SECONDS` so the fiber can't hold a semaphore slot longer
    than expected
  - This ensures that even if `Fetcher.pull()` hangs beyond its configured
    timeout, the feed fetch is force-aborted
  - On timeout, return the error feed (or stale cache) and release the semaphore

### Step 4: Harden VugAdapter Favicon Fetch

- [ ] In `src/fetcher/feed_fetcher.cr` `safe_get_favicon_with_fallback()`:
  - Verify the existing rescue clauses catch all timeout/hang scenarios
  - Consider wrapping the VugAdapter call in a `select` with a timeout
    (e.g., 5-10s) so favicon fetching never blocks the main fetch pipeline
  - If the favicon can't be fetched quickly, skip it and use the Google
    favicon fallback

### Step 5: Reduce Batch Fetch Timeout in refresh_loop.cr

- [ ] In `src/fetcher/refresh_loop.cr` `fetch_feeds_concurrently()`:
  - Review the `select` with `timeout_span` — ensure it's using
    `FEED_FETCH_TIMEOUT_SECONDS` correctly
  - Consider logging which feeds are still pending when the timeout fires,
    to aid diagnosis

### Step 6: Compile & Verify

- [ ] Run `just nix-build` to verify the project compiles
- [ ] Fix any compilation errors
- [ ] Review changes for correctness — no behavior changes except reduced
      timeout/hang risk

## Documentation Requirements

**Must Update:** None
**Check If Affected:** None

## Completion Criteria

- [ ] Per-feed wall-clock timeout is enforced regardless of underlying HTTP behavior
- [ ] VugAdapter favicon fetch cannot block the feed fetch pipeline
- [ ] Batch fetch timeout is reasonable for 207 feeds with 8 concurrent slots
- [ ] `just nix-build` passes
- [ ] No behavior regressions — feeds still fetch successfully, retries still work
