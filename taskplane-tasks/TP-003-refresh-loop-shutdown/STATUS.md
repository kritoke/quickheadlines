# STATUS — TP-003

## Current Step: Step 0
## Progress

### Step 0: Preflight
- [ ] Verify PROMPT.md is readable
- [ ] Verify STATUS.md exists
- [ ] Read refresh_loop.cr and identify all 3 broken shutdown checks

### Step 1: Fix Shutdown Pattern
- [ ] Replace instance 1 (after initial refresh sleep)
- [ ] Replace instance 2 (after config-change refresh sleep)
- [ ] Replace instance 3 (in rescue block sleep)

### Step 2: Verify Correctness
- [ ] Trace loop logic
- [ ] Confirm StateStore.refreshing = false in ensure
- [ ] Confirm spawn block completes cleanly

### Step 3: Compile & Verify
- [ ] `just nix-build` passes

## Discoveries
_(worker fills this in)_

## Review History
_(worker fills this in)_
