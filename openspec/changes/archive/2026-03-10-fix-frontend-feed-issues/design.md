## Context

The feeds page (`frontend/src/routes/+page.svelte`) has multiple bugs in its state management and API interaction:

**Current State**:
- Inline state management (feeds, tabs, lastUpdated, etc.) in page component
- Multiple competing refresh intervals created in different places
- No proper error handling for cancelled requests
- API responses partially used (missing lastUpdated, tabs)

**Root Causes**:
1. Incomplete refactor - stores exist but aren't used
2. Duplicated interval logic in `loadConfig()` and `$effect`
3. Missing data assignment after successful fetch
4. API error handling shows toast for all errors including AbortError

## Goals / Non-Goals

**Goals:**
- Fix feed retrieval by properly assigning API response data
- Eliminate memory leaks from duplicate intervals
- Improve UX by hiding expected errors (aborted requests)
- Add basic resilience (timeout, deduplication)

**Non-Goals:**
- Migrating to stores (separate change)
- WebSocket infrastructure changes (already working)
- Search behavior changes (stays as-is)
- Performance optimizations beyond critical fixes

## Decisions

### Decision 1: Keep inline state management
**Rationale**: Quick fix path. Store migration can happen in separate change.

**Alternatives Considered**:
- Migrate to stores now: Rejected - too large for critical fix scope
- Remove stores entirely: Rejected - they'll be needed for future work

### Decision 2: Single reactive refresh interval
**Approach**: Use `$effect` with `refreshMinutes` dependency to recreate interval when config changes

**Implementation**:
```typescript
// Reactive interval - recreates when refreshMinutes changes
$effect(() => {
    if (refreshInterval) clearInterval(refreshInterval);
    
    refreshInterval = setInterval(() => {
        if (pageVisible) loadFeeds(activeTab, true);
    }, refreshMinutes * 60 * 1000);
    
    return () => {
        if (refreshInterval) clearInterval(refreshInterval);
    };
});
```

**Alternatives Considered**:
- Manual interval management: Rejected - error-prone
- Keep multiple intervals: Rejected - causes current bug

### Decision 3: AbortError special handling
**Approach**: Check `error.name === 'AbortError'` before showing toast

**Rationale**: Aborted requests are normal during tab switches, not user-facing errors

### Decision 4: 30-second request timeout
**Rationale**: Prevent indefinite hangs, reasonable for feed fetch

**Alternatives Considered**:
- 10s timeout: Too aggressive for slow connections
- 60s timeout: Too long for good UX
- No timeout: Current behavior, causes hangs

### Decision 5: Request deduplication via Map
**Approach**: Track in-flight requests, return existing promise for duplicate calls

**Rationale**: Prevents race conditions when user rapidly switches tabs

## Risks / Trade-offs

**Risk**: Fix doesn't address underlying store architecture debt
→ **Mitigation**: Create follow-up change for store migration

**Risk**: Timeout might be too aggressive for large feeds
→ **Mitigation**: 30s is conservative; can increase if needed

**Risk**: Deduplication might hide real issues if requests legitimately need to be separate
→ **Mitigation**: Dedup is per-tab, different tabs can fetch concurrently

**Trade-off**: Keeping inline state means we still have duplicate state management patterns
→ **Acceptance**: Critical fix priority over architectural perfection

## Migration Plan

**Phase 1: Feed Retrieval Fix** (Immediate)
1. Add `lastUpdated` assignment from response
2. Add `tabs` assignment from response
3. Update cache with correct timestamp

**Phase 2: Interval Consolidation** (After Phase 1 verified)
1. Remove interval creation from `loadConfig()`
2. Consolidate to single reactive `$effect`
3. Test with various refresh intervals

**Phase 3: Error Handling** (After Phase 2 verified)
1. Add AbortError check in api.ts
2. Add 30s timeout
3. Add request deduplication

**Rollback**: Simple - revert individual commits. Each phase is independent.

## Open Questions

None - all decisions made based on critical fix requirements.
