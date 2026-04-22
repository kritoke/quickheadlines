## Why

The backend codebase has accumulated technical debt that reduces maintainability and testability: duplicate `AppState` class definitions, global singletons, non-functional locking primitives, silent error handling, and module-level private functions. These issues make the code harder to reason about, test in isolation, and extend safely.

## What Changes

### Code Quality Improvements

1. **Consolidate `AppState` classes** - Merge the two `AppState` class definitions in `models.cr` (lines 82-128 and 216-296) into a single coherent class
2. **Eliminate global singletons** - Replace `STATE` global and `FEED_CACHE` global with dependency-injected instances or proper singleton patterns
3. **Remove fake `with_lock`** - Either implement actual locking or remove the misleading method that just `yield`s
4. **Fix silent error handling** - Replace empty `rescue` blocks with proper error logging or propagation
5. **Encapsulate fetcher logic** - Move module-level `private def` functions in `feed_fetcher.cr` into a `FeedFetcher` class

### Non-Breaking Changes
- All existing APIs and interfaces remain unchanged
- Internal refactoring only - no public API changes
- Database schema unchanged
- Frontend unchanged

## Capabilities

### New Capabilities
- `state-management`: Formalized state management with single source of truth, proper encapsulation, and thread-safe access patterns

### Modified Capabilities
- None - this is internal refactoring with no spec-level behavior changes

## Impact

### Affected Files
- `src/models.cr` - Consolidate AppState, remove globals
- `src/fetcher/feed_fetcher.cr` - Encapsulate in class, fix error handling
- `src/software_fetcher.cr` - Improve error handling
- `src/services/feed_service.cr` - May need updates for new state access patterns
- `src/storage/feed_cache.cr` - May need updates for singleton pattern

### Dependencies
- No external dependency changes
- No breaking changes to public APIs

### Risk Assessment
- **Low Risk**: Changes are internal refactoring with no API changes
- **Testing**: Existing tests should pass; may need minor updates for new class structure
- **Rollback**: Straightforward git revert if issues arise
