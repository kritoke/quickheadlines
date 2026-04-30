# Task: TP-003 — Fix Refresh Loop Shutdown Logic

**Created:** 2026-04-30
**Size:** S

## Review Level: 0 (None)

**Assessment:** Small, focused fix — the shutdown pattern is clearly broken and the fix is straightforward.
**Score:** 2/8 — Blast radius: 0, Pattern novelty: 0, Security: 0, Reversibility: 1

## Canonical Task Folder

```
taskplane-tasks/TP-003-refresh-loop-shutdown/
├── PROMPT.md   ← This file (immutable above --- divider)
├── STATUS.md   ← Worker updates this
├── .reviews/   ← Reviewer output
└── .DONE       ← Created when complete
```

## Mission

Fix the broken shutdown pattern in the refresh loop that prevents graceful
shutdown and relies on the 5-second `Process.exit(1)` force-kill instead.

## Problem Analysis

### The Bug

In `src/fetcher/refresh_loop.cr`, the shutdown check pattern is:

```crystal
sleep (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE).seconds
next unless QuickHeadlines.shutting_down?
next
```

This pattern appears at **3 locations** (lines ~132, ~164, ~193).

**What's wrong:** `next unless shutting_down?; next` means:
- If NOT shutting down → `next` (continue loop) ✓
- If shutting down → `next` (continue loop) ✗ — should `break`!

The `next` after the `unless` **always executes**, so the check is a no-op.
The refresh loop never actually stops on shutdown.

### Correct Pattern

The intent is clearly to break out of the loop when shutting down:

```crystal
sleep (active_config.refresh_minutes * QuickHeadlines::Constants::SECONDS_PER_MINUTE).seconds
break if QuickHeadlines.shutting_down?
```

### Why It Matters

- The refresh loop holds references to `FeedCache`, `DatabaseService`, and `Config`
- On shutdown, the database close fails with "database is locked" because the
  refresh loop is still running
- The 5-second force-kill in `src/quickheadlines.cr` masks this issue but means
  the database doesn't get a clean checkpoint/WAL flush

## Dependencies

- **Depends on: TP-001** — Fixing shutdown while the DB is still heavily contended
  could mask the issue. Fix DB contention first so shutdown can be verified clean.

## Context to Read First

- `src/fetcher/refresh_loop.cr` — The broken shutdown pattern (3 locations)
- `src/module.cr` — `QuickHeadlines.shutting_down?` definition
- `src/quickheadlines.cr` — The force-kill fallback and shutdown signal handling

## Environment

- **Workspace:** Project root
- **Language:** Crystal (>= 1.18.0)
- **Services required:** None

## File Scope

- `src/fetcher/refresh_loop.cr` — Fix 3 instances of the broken pattern

## Steps

### Step 0: Preflight

- [ ] Verify this PROMPT.md is readable
- [ ] Verify STATUS.md exists in the same folder
- [ ] Read `src/fetcher/refresh_loop.cr` and identify all 3 broken shutdown checks

### Step 1: Fix Shutdown Pattern

- [ ] Replace all instances of:
  ```crystal
  next unless QuickHeadlines.shutting_down?
  next
  ```
  with:
  ```crystal
  break if QuickHeadlines.shutting_down?
  ```

  There are 3 occurrences in `start_refresh_loop()`:
  - After the initial refresh sleep (~line 132)
  - After the config-change refresh sleep (~line 164)
  - In the rescue block's sleep (~line 193)

### Step 2: Verify Correctness

- [ ] Trace the loop logic mentally to confirm `break` exits the `loop do` block
- [ ] Confirm that `StateStore.refreshing = false` is set after the loop exits
  (it's in the `ensure` block, so it should be fine)
- [ ] Confirm the outer `spawn` block will complete cleanly after the loop breaks

### Step 3: Compile & Verify

- [ ] Run `just nix-build` to verify the project compiles
- [ ] Fix any compilation errors

## Documentation Requirements

**Must Update:** None
**Check If Affected:** None

## Completion Criteria

- [ ] All 3 shutdown checks use `break if QuickHeadlines.shutting_down?`
- [ ] `just nix-build` passes
- [ ] No other changes to refresh loop behavior
