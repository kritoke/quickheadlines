## 1. Dead Code Removal

- [x] 1.1 Remove unused `REFRESH_MUTEX` from `refresh_loop.cr:12`
- [x] 1.2 Remove unused `FeedData.with_items()` from `models.cr:38-40`
- [x] 1.3 Remove empty `ws.on_message` handler from `quickheadlines.cr:63-64`
- [x] 1.4 Remove commented-out constants from `cache_utils.cr:15-18`
- [x] 1.5 Verify build: `just nix-build`

## 2. Remove ADI::Register Annotations

- [x] 2.1 Remove `@[ADI::Register]` from `StoryRepository`, `FeedRepository`, `ClusterRepository`
- [x] 2.2 Remove `@[ADI::Register]` from `FeedCache`, `DatabaseService`, `FeedFetcher`
- [x] 2.3 Remove `@[ADI::Register]` and `@[ADI::AsAlias]` from `ErrorRenderer`
- [x] 2.4 Verify build: `just nix-build`

## 3. Eliminate Domain::TimelineEntry

- [x] 3.1 Move `TimelineEntry` record into `StoryRepository` as a private struct
- [x] 3.2 Update `StoryService.get_timeline()` to use the private type
- [x] 3.3 Delete `domain/items.cr` and remove its `require` from `application.cr`
- [x] 3.4 Verify build: `just nix-build`

## 4. Standardize DTO Serialization on JSON::Serializable

- [x] 4.1 Migrate `ConfigResponse` from `ASR::Serializable` to `JSON::Serializable`
- [x] 4.2 Migrate `ClustersResponse` and `ClusterItemsResponse` from `ASR::Serializable` to `JSON::Serializable`
- [x] 4.3 Remove `ASR::Serializable` from `StoryResponse` (keep `JSON::Serializable`)
- [x] 4.4 Remove `ATH::View` wrapper from `ConfigController.config()` — return `ConfigResponse` directly
- [x] 4.5 Remove `ATH::View` wrapper from `TabsController.tabs()` — return `TabsResponse` directly
- [x] 4.6 Verify build: `just nix-build`

## 5. Remove Entities::Feed

- [x] 5.1 Add `find_all_urls() : Set(String)` to `FeedRepository`
- [x] 5.2 Update `AdminController.handle_cleanup_orphaned()` to use `find_all_urls()`
- [x] 5.3 Remove `read_feed_entity()` and `find_all()` from `FeedRepository`
- [x] 5.4 Delete `entities/feed.cr` and remove its `require` from `application.cr`
- [x] 5.5 Verify build: `just nix-build`

## 6. Fix favicon_data Propagation

- [x] 6.1 Add `favicon_data` to SQL query in `StoryRepository.find_timeline_items()` and propagate through `StoryService` to `TimelineItemResponse`
- [x] 6.2 Add `favicon_data` to SQL query in `ClusterRepository` and populate it in `Entities::Story` construction
- [x] 6.3 Fix `ClusteringService.get_cluster_items_response()` to use correct `favicon_data` field instead of copying `favicon`
- [x] 6.4 Verify frontend does not use `favicon_data` on feed objects, then remove from `FeedResponse` DTO — SKIPPED: frontend uses `favicon_data` as fallback in FeedBox and feedItem utils
- [x] 6.5 Verify build: `just nix-build`

## 7. Simplify FeedCache Initialization

- [x] 7.1 Remove dual DB init: make `db_service` parameter non-optional `DatabaseService`, remove standalone `DB.open()` fallback
- [x] 7.2 Update `FeedCache.load_feed_cache()` to pass `DatabaseService` without fallback
- [x] 7.3 Verify build: `just nix-build`

## 8. Resolve Circular Dependency

- [x] 8.1 Remove forward declaration of `QuickHeadlines::Application` from `database_service.cr`
- [x] 8.2 Remove `DatabaseService.instance` class-level singleton — kept singleton but removed circular dependency
- [x] 8.3 Update `AppBootstrap` to create `DatabaseService.new(config)` and pass it to consumers
- [x] 8.4 Audit and update all `DatabaseService.instance` call sites to receive via constructor
- [x] 8.5 Verify build: `just nix-build`

## 9. Standardize Transaction Management

- [x] 9.1 Convert manual `BEGIN`/`COMMIT`/`ROLLBACK` in `ClusteringStore` to `@db.transaction { }` blocks
- [x] 9.2 Verify build: `just nix-build`

## 10. Clean Up Module-Level State

- [x] 10.1 Convert `QuickHeadlines::Storage.last_cache_cleanup` to a local variable in `save_feed_cache()` — SKIPPED: module-level state is needed for hourly throttle across refresh cycles; cannot be local
- [x] 10.2 Verify build: `just nix-build`

## 11. Final Verification

- [x] 11.1 Run `just nix-build` — full build passes
- [x] 11.2 Run `nix develop . --command crystal spec` — all specs pass
- [x] 11.3 Run `cd frontend && npm run test` — frontend tests pass
