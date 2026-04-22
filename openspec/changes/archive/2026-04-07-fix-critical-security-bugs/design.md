## Context

Four critical and four high severity bugs were identified in a security-focused code review. These span authentication gaps, race conditions, data inconsistency, and unhandled error paths. The fixes are localized but touch multiple layers: controllers, models, WebSocket infrastructure, and repositories.

## Goals / Non-Goals

**Goals:**
- Fix all 4 critical issues
- Fix all 4 high severity issues
- Ensure no regression in existing functionality
- Clean up debug console.log statements from production frontend code

**Non-Goals:**
- No new features or capabilities
- No database schema changes
- No API contract changes (except adding auth to `/api/header_color`)
- No refactoring of working code beyond what's necessary for the fix

## Decisions

### 1. Auth on `/api/header_color` — add `check_admin_auth` guard

**Choice:** Add auth check to `HeaderColorController` rather than removing the endpoint or making it admin-only only.
**Rationale:** Header color customization is an administrative function. Adding auth is the minimal, correct fix. Using the existing `check_admin_auth` method in `ApiBaseController` ensures consistent auth patterns across the codebase.

### 2. Clustering state — use single mutex for all mutations

**Choice:** Add `@@clustering_mutex` to all methods that read/write `@@current.clustering`. Remove the `@@mutex` usage for clustering-specific state.
**Rationale:** Two separate mutexes protecting overlapping state create a TOCTOU race. The `start_clustering_if_idle` check (which sets `clustering = true`) must be atomic with the `clustering=(value)` setter when value=false. Single mutex ensures total order of all clustering state changes.
**Alternative considered:** Using an atomic boolean. Crystal's `Atomic(Bool)` exists but `clustering` is part of a larger snapshot record, so a dedicated mutex is cleaner.

### 3. SocketManager IP count — remove direct decrement from cleanup

**Choice:** `cleanup_dead_connections` will close channels and set clustering=false, but NOT call `decrement_ip_count`. The writer_fiber's `Channel::ClosedError` handler will always call `unregister_connection`, which is the single source of truth for IP count cleanup.
**Rationale:** The existing comment at line 145-147 correctly identifies the double-decrement problem. The fix is to make cleanup_dead_connections behave like `unregister` — close the channel only, let the writer fiber handle the rest.

### 4. Timeline count query — add representative filter

**Choice:** Mirror the `cluster_info` CTE and `i.id = ci.representative_id` filter in `count_timeline_items`.
**Rationale:** The pagination calculation in `StoryService.get_timeline` (`has_more = offset + limit < total_count`) depends on an accurate count. The fix must preserve the semantics: only representative items are visible, so only they should be counted.

### 5. EventBroadcaster stats — remove increment from send path

**Choice:** Remove `PROCESSED_EVENTS.add(1)` from `notify_feed_update` (line 30). Keep it only in the broadcast loop (line 16).
**Rationale:** The channel send is an internal handoff, not delivery. Only actual socket delivery should count as processed.

### 6. Admin clear-cache — add transaction wrapper

**Choice:** Wrap `DELETE FROM items` + `DELETE FROM feeds` + `cache.clear_clustering_metadata` + `cache.clear_all` in a BEGIN/COMMIT block inside the spawn.
**Rationale:** Prevents partial state if the process crashes mid-operation.

### 7. Time parsing — add begin/rescue for `Time::Format::Error`

**Choice:** Wrap `Time.parse` calls in repositories with `begin/rescue` that returns `nil` for unparseable dates.
**Rationale:** Corrupt database values shouldn't crash the entire API response. Missing or null dates are handled gracefully elsewhere in the codebase.

### 8. Console.log cleanup — remove from production files

**Choice:** Remove debug logging from `frontend/src/lib/api.ts` and `frontend/src/lib/stores/feedStore.svelte.ts`.
**Rationale:** No good reason to ship debug logs to production browsers.

## Risks / Trade-offs

- [Risk] Changing clustering mutex behavior could introduce new race if mutex usage isn't consistent across all callers. → **Mitigation**: Audit all callers of `StateStore.clustering=` and `start_clustering_if_idle` to ensure they don't hold the mutex across yield points.
- [Risk] Auth on `/api/header_color` may break existing frontend behavior if users were relying on auto-save of colors. → **Mitigation**: This is an admin feature by design; check that frontend doesn't auto-save colors without auth token.
- [Risk] Fixing the count query adds a JOIN that could slow timeline loads slightly. → **Mitigation**: The `cluster_info` CTE is already used in `find_timeline_items` and is well-indexed; same plan works for count.

## Migration Plan

All changes are backward-compatible bug fixes. Deploy in a single release:

1. Apply all fixes
2. Run `just nix-build` to verify compilation
3. Run tests: `nix develop . --command crystal spec && cd frontend && npm run test`
4. Deploy

No rollback needed — all changes are additive and fix incorrect behavior.

## Open Questions

- None — all decisions are made and localized to specific files.