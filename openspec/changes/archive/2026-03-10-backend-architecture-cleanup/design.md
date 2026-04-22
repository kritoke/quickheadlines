## Context

The QuickHeadlines backend has evolved organically, resulting in several architectural issues:

1. **Duplicate AppState classes** (`models.cr:82-128` and `models.cr:216-296`) - Two classes with the same name, one instance-based, one static, both delegating to `StateStore`
2. **Global singletons** - `STATE = AppState.new` and `FEED_CACHE = FeedCache.instance` create implicit dependencies
3. **Fake locking** - `AppState.with_lock` just `yield`s with a comment claiming `StateStore` handles it
4. **Silent error handling** - Empty `rescue` blocks in `feed_fetcher.cr` (lines 101-102, 111-112, 136-137)
5. **Module-level functions** - ~20 `private def` at top level in `feed_fetcher.cr` instead of encapsulated in a class

## Goals / Non-Goals

**Goals:**
- Single `AppState` class with clear responsibilities
- Proper singleton or dependency injection for `FeedCache`
- Remove or implement `with_lock` properly
- Replace silent error handling with explicit logging
- Encapsulate fetcher logic in a `FeedFetcher` class

**Non-Goals:**
- Complete rewrite of state management
- Changes to public APIs
- Frontend changes
- Database schema changes
- New features

## Decisions

### D1: Consolidate AppState into single class

**Decision:** Merge both `AppState` classes into a single class that:
- Uses `StateStore` internally for thread-safe state access
- Provides both instance and class-level methods for backward compatibility
- Removes the misleading `with_lock` method

**Rationale:** Having two classes with the same name is confusing. The instance-based version (line 82) is only instantiated once as `STATE`. The static version (line 216) is what's actually used throughout the codebase.

**Alternative considered:** Keep both but rename one. Rejected because they serve the same purpose.

### D2: Remove `with_lock` entirely

**Decision:** Delete `AppState.with_lock` and `AppState.self.with_lock` methods.

**Rationale:** These methods do nothing (just `yield`) and create false confidence. `StateStore.update` already handles mutex synchronization internally. The methods are not used anywhere meaningful.

### D3: Replace empty rescue blocks with explicit logging

**Decision:** Replace:
```crystal
rescue
end
```
With:
```crystal
rescue ex
  HealthMonitor.log_error("context", ex)
end
```

**Rationale:** Silent failures make debugging impossible. Even if we don't want to propagate the error, we should log it.

### D4: Create FeedFetcher class

**Decision:** Create a `FeedFetcher` class that encapsulates all fetcher logic:
- Instance methods instead of module-level `private def`
- Accepts `FeedCache` as constructor dependency (enables testing)
- `fetch_feed` becomes instance method

**Rationale:** Encapsulation, testability, clearer ownership of code.

**Alternative considered:** Keep as-is with better naming. Rejected because module-level privates are not idiomatic Crystal.

### D5: Keep STATE and FEED_CACHE globals for now

**Decision:** Keep `STATE` and `FEED_CACHE` globals but add deprecation comments. Full DI refactoring is out of scope.

**Rationale:** Removing these globals would require changes across many files. This can be done incrementally in a follow-up change.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Breaking existing AppState usage | Keep all existing method signatures, just consolidate implementation |
| FeedFetcher changes break fetch logic | Run full test suite, verify with sample feeds |
| Error logging increases noise | Use appropriate log levels (debug for expected failures) |
| StateStore concurrency issues | No changes to StateStore locking logic |

## Migration Plan

1. **Phase 1: AppState consolidation**
   - Merge instance methods into static class
   - Delete duplicate class definition
   - Remove `with_lock` methods
   - Run tests

2. **Phase 2: Error handling**
   - Replace empty rescue blocks
   - Verify error paths still work

3. **Phase 3: FeedFetcher class**
   - Create class
   - Move private functions
   - Update callers
   - Run tests

**Rollback:** Each phase can be reverted independently via git.

## Open Questions

- Should we add a proper DI container? (Deferred to future change)
- Should `FeedFetcher` be a singleton or instantiated per-request? (Recommend singleton for now)
