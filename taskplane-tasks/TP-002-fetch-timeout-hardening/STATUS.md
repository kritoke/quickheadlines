# STATUS — TP-002

## Current Step: Step 0
## Progress

### Step 0: Preflight
- [ ] Verify PROMPT.md is readable
- [ ] Verify STATUS.md exists
- [ ] Read all context files

### Step 1: Reduce Per-Feed Wall-Clock Timeout
- [ ] Update FETCH_TIMEOUT_SECONDS
- [ ] Ensure should_abort_fetch? is authoritative

### Step 2: Reduce Overall Batch Fetch Timeout
- [ ] Update FEED_FETCH_TIMEOUT_SECONDS

### Step 3: Add Per-Feed Timeout Enforcement
- [ ] Wrap retry loop in select with timeout
- [ ] Return error/stale cache on timeout

### Step 4: Harden VugAdapter Favicon Fetch
- [ ] Verify rescue clauses
- [ ] Add timeout wrapper for VugAdapter calls

### Step 5: Reduce Batch Fetch Timeout in refresh_loop.cr
- [ ] Review fetch_feeds_concurrently timeout handling
- [ ] Add diagnostic logging on timeout

### Step 6: Compile & Verify
- [ ] `just nix-build` passes
- [ ] Review changes

## Discoveries
_(worker fills this in)_

## Review History
_(worker fills this in)_
