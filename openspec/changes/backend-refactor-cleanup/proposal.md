## Why

The backend has accumulated multiple half-finished refactors and dead code over time. Two major refactoring efforts — migrating to an entity/DTO/repository pattern and adopting Athena's DI system — were started but never completed, leaving old and new patterns coexisting throughout the codebase. Dead code, inconsistent patterns, and broken `favicon_data` handling add maintenance burden and confusion.

## What Changes

- **Remove dead code**: Unused `REFRESH_MUTEX`, `FeedData.with_items()`, commented-out constants, empty `ws.on_message` handler
- **Remove unused `ADI::Register` annotations**: All 7 are decorative — controllers use manual singletons
- **Eliminate `Domain::TimelineEntry`**: Leaky abstraction from StoryRepository through StoryService; make it private or inline
- **Standardize DTO serialization on `JSON::Serializable`**: Remove `ASR::Serializable` from `ConfigResponse`, `ClustersResponse`, `ClusterItemsResponse`, `StoryResponse`
- **Remove `ATH::View` wrappers**: Only 2 uses, both unnecessary — return DTOs directly
- **Remove `Entities::Feed`**: Nearly dead (only consumer accesses `.url`); replace with direct query
- **Fix `favicon_data` propagation bugs**: Timeline and cluster responses always get `nil`; `clustering_service` copies wrong field
- **Remove `favicon_data` from `FeedResponse` DTO**: Frontend doesn't need internal filesystem paths
- **Remove dual DB init in `FeedCache`**: Always require `DatabaseService`, remove standalone fallback
- **Resolve circular dependency**: `DatabaseService` reads `Application.initial_config` via forward declaration; pass config explicitly
- **Standardize transaction management**: Convert manual `BEGIN`/`COMMIT`/`ROLLBACK` to `@db.transaction` blocks
- **Clean up module-level state**: Convert `Storage.last_cache_cleanup` to local variable

## Capabilities

### New Capabilities
_None — this is a cleanup refactor with no new features._

### Modified Capabilities
_None — all changes are internal implementation details. The public API contract (DTOs returned to the frontend) is preserved. The `favicon_data` field is removed from `FeedResponse` DTO but the frontend already doesn't use it (it uses `favicon` for the proxy endpoint)._

## Impact

- **Crystal source files**: ~25 files touched across controllers, services, repositories, storage, and DTOs
- **No API contract changes**: DTOs that the frontend consumes remain stable (except removing unused `favicon_data` from `FeedResponse`)
- **No dependency changes**: No new shards or version changes
- **No database schema changes**: Favicon data cleanup is in-memory/application-level only
- **Build verification required**: Each phase needs `just nix-build` + `crystal spec`
