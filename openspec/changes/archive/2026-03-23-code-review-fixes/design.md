## Context

QuickHeadlines is an RSS reader with two main views (feed box and timeline) that share tab-based filtering. The current implementation has several issues:

1. **Mobile tab navigation missing on timeline**: The timeline view (`/timeline`) doesn't render the mobile `TabSelector` component, making it impossible to change tabs on mobile devices.

2. **State inconsistency**: Each view loads tabs independently - feed view gets tabs from `/api/feeds`, timeline view makes a separate call to `fetchFeeds('all')` just to extract tab names. This causes:
   - Race conditions when tabs are added/modified
   - Duplicate API calls
   - Different views showing different tabs

3. **Security**: The image proxy endpoint (`/proxy_image`) accepts any URL without validation, potential SSRF vulnerability.

4. **Missing rate limiting**: Expensive endpoints like `/api/cluster` can be abused.

## Goals / Non-Goals

**Goals:**
- Add mobile TabSelector to timeline view
- Create shared state store for tabs/activeTab
- Add URL validation to proxy endpoint
- Add rate limiting to expensive endpoints
- Reduce duplicate effects code
- Add lightweight tabs API endpoint

**Non-Goals:**
- Full user authentication system
- Complete rewrite of state management (incremental improvement)
- Complex caching strategies
- Database schema changes

## Decisions

### D1: Shared State Architecture
**Decision**: Create a new `stores/appState.svelte.ts` for cross-cutting state.

**Rationale**: 
- Current pattern has each view manage its own tabs
- Svelte 5's module-level `$state` allows easy sharing
- Avoids prop drilling through components

**Alternatives considered**:
- Use SvelteKit's built-in page stores - doesn't work well for cross-page state
- Use URL-only state - causes excessive API calls on every navigation

### D2: Mobile TabSelector Placement
**Decision**: Place mobile TabSelector outside header, fixed at top-14 (56px), matching feed page pattern.

**Rationale**:
- Maintains consistency with existing feed page design
- Fixed position allows easy access while scrolling
- Z-index of 40 ensures proper stacking

### D3: Proxy URL Validation - Domain Allowlist
**Decision**: Use a domain allowlist approach rather than blocklist.

**Rationale**:
- Blocklists are inherently incomplete (new malicious domains constantly emerge)
- RSS feeds typically come from known image hosts
- Allowlist is more secure by default

**Implementation**:
- List: `i.imgur.com`, `pbs.twimg.com`, `avatars.githubusercontent.com`, `lh3.googleusercontent.com`, `i.pravatar.cc`
- Simple string matching on `uri.host`

### D4: Rate Limiting Strategy
**Decision**: Simple in-memory rate limiting with token bucket.

**Rationale**:
- Minimal dependency (no Redis needed)
- Works for single-instance deployment
- Can be extended later for multi-instance

**Parameters**:
- `/api/cluster`: 1 request per minute
- `/api/admin`: 1 request per minute

### D5: Effects Consolidation
**Decision**: Create a shared effect base that both `createFeedEffects` and `createTimelineEffects` use.

**Rationale**:
- 84% code duplication currently exists
- Easier to maintain single implementation
- Reduces chance of divergence between views

## Risks / Trade-offs

**[Risk] Global state becoming source of truth issues**
→ **Mitigation**: Make stores update-only from API; UI actions go through store functions
→ **Mitigation**: Add change detection to warn on stale data

**[Risk] Mobile tab selector breaking timeline layout**
→ **Mitigation**: Use exact same pattern as feed page (tested)
→ **Mitigation**: Add CSS spacer below header to prevent overlap

**[Risk] Rate limiting blocking legitimate admin use**
→ **Mitigation**: High limits (1/min) allow normal use but prevent abuse
→ **Mitigation**: Return 429 with Retry-After header

**[Risk] Adding new store increases complexity**
→ **Mitigation**: Keep store minimal - only truly cross-cutting state
→ **Mitigation**: Document that feed-specific state stays in feedStore

## Migration Plan

1. **Phase 1**: Add mobile TabSelector to timeline (low risk, isolated change)
2. **Phase 2**: Create `appState` store and wire to timeline page (medium risk)
3. **Phase 3**: Add proxy URL validation (low risk, defensive)
4. **Phase 4**: Add rate limiting (low risk, non-breaking)
5. **Phase 5**: Refactor effects (low risk, internal)
6. **Phase 6**: Add `/api/tabs` endpoint and replace inline calls (medium risk)

**Rollback**: Each phase is independently deployable. If issues arise:
- Phase 1-2: Revert to old timeline page
- Phase 3: Remove validation check (allow all)
- Phase 4: Disable rate limiting middleware
- Phase 5: Revert effects file
- Phase 6: Continue using existing inline tab loading

## Open Questions

1. **Should appState include user preferences (theme, layout)?**
   - Currently in `theme.svelte.ts` and `layout.svelte.ts`
   - Keep separate for now; can consolidate later if needed

2. **How to handle tab changes during active feed refresh?**
   - Current: cancel pending and start new
   - Alternative: queue changes
   - Decision: cancel pending (simpler, immediate feedback)

3. **Rate limiting across multiple instances?**
   - Single instance for now; can add Redis later
   - Document limitation in code comments