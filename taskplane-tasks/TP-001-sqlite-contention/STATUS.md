# STATUS — TP-001

## Current Step: Step 0
## Progress

### Step 0: Preflight
- [ ] Verify PROMPT.md is readable
- [ ] Verify STATUS.md exists
- [ ] Read all context files
- [ ] Understand DB write patterns and contention points

### Step 1: Increase Connection Pool & Tune SQLite PRAGMAs
- [ ] Update constants
- [ ] Update PRAGMAs
- [ ] Update connection string

### Step 2: Reduce Concurrent Clustering Writers
- [ ] Review clustering write paths
- [ ] Batch/serialize writes
- [ ] Reduce MAX_PARALLEL_CLUSTERING

### Step 3: Separate Read and Write Concerns
- [ ] Review upsert_with_items transaction usage
- [ ] Review FeedCache mutex strategy

### Step 4: Verify VACUUM/Cleanup Safety
- [ ] Ensure VACUUM checks for active refreshes
- [ ] Verify WAL checkpoint settings

### Step 5: Compile & Verify
- [ ] `just nix-build` passes
- [ ] Review changes for correctness

## Discoveries
_(worker fills this in)_

## Review History
_(worker fills this in)_
