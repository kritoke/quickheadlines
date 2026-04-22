## ADDED Requirements

### Requirement: Dead code removal
The backend SHALL NOT contain unused declarations, dead imports, or stub code that is never loaded.

#### Scenario: Unused mutex declaration
- **WHEN** `REFRESH_MUTEX` is referenced in `refresh_loop.cr`
- **THEN** it SHALL be removed since `REFRESH_IN_PROGRESS` (Atomic) is the actual guard

#### Scenario: Unused FeedData method
- **WHEN** `FeedData.with_items()` exists in `models.cr`
- **THEN** it SHALL be removed since it has zero callers

#### Scenario: Empty WebSocket handler
- **WHEN** `ws.on_message` handler body is empty in `quickheadlines.cr`
- **THEN** the empty handler block SHALL be removed

#### Scenario: Commented-out constants
- **WHEN** `cache_utils.cr` contains commented-out constant assignments (lines 15-18)
- **THEN** they SHALL be removed

### Requirement: Remove unused ADI annotations
The backend SHALL NOT contain `@[ADI::Register]` annotations on classes that are instantiated via manual singletons.

#### Scenario: ADI annotations on services
- **WHEN** `FeedCache`, `DatabaseService`, `FeedFetcher` have `@[ADI::Register]`
- **THEN** annotations SHALL be removed since controllers access them via `.instance`

#### Scenario: ADI annotations on repositories
- **WHEN** `StoryRepository`, `FeedRepository`, `ClusterRepository` have `@[ADI::Register]`
- **THEN** annotations SHALL be removed since they are instantiated directly

#### Scenario: ADI annotations on error renderer
- **WHEN** `ErrorRenderer` has `@[ADI::Register]` and `@[ADI::AsAlias]`
- **THEN** both annotations SHALL be removed

### Requirement: Eliminate Domain::TimelineEntry leak
The `TimelineEntry` record SHALL NOT be exposed outside of `StoryRepository`.

#### Scenario: StoryRepository returns TimelineEntry
- **WHEN** `StoryRepository.find_timeline_items()` returns `Array(TimelineEntry)`
- **THEN** `TimelineEntry` SHALL become a private struct inside `StoryRepository` or the query results SHALL be returned as `TimelineItemResponse` DTOs directly

#### Scenario: Domain items file cleanup
- **WHEN** `domain/items.cr` is no longer needed
- **THEN** the file and its `require` in `application.cr` SHALL be removed

### Requirement: Standardize DTO serialization
All DTOs SHALL use `JSON::Serializable` exclusively. No DTO SHALL use `ASR::Serializable`.

#### Scenario: ConfigResponse serialization
- **WHEN** `ConfigResponse` in `config_dto.cr` uses `ASR::Serializable`
- **THEN** it SHALL be migrated to `JSON::Serializable` with manual `to_json` if needed

#### Scenario: Cluster DTOs serialization
- **WHEN** `ClustersResponse` and `ClusterItemsResponse` in `cluster_dto.cr` use `ASR::Serializable`
- **THEN** they SHALL be migrated to `JSON::Serializable`

#### Scenario: StoryResponse dual serialization
- **WHEN** `StoryResponse` in `story_dto.cr` includes both `ASR::Serializable` and `JSON::Serializable`
- **THEN** only `JSON::Serializable` SHALL remain

#### Scenario: ATH::View wrapper removal
- **WHEN** `ConfigController.config()` returns `ATH::View(ConfigResponse)`
- **THEN** it SHALL return `ConfigResponse` directly
- **WHEN** `TabsController.tabs()` returns `ATH::View(TabsResponse)`
- **THEN** it SHALL return `TabsResponse` directly

### Requirement: Remove Entities::Feed
The `Entities::Feed` record SHALL be removed. Its sole consumer SHALL use a direct query instead.

#### Scenario: AdminController orphan cleanup
- **WHEN** `AdminController.handle_cleanup_orphaned()` calls `feed_repo.find_all()` and only accesses `.url`
- **THEN** a new `FeedRepository.find_all_urls()` method returning `Set(String)` SHALL replace it

#### Scenario: Entities feed file cleanup
- **WHEN** `Entities::Feed` and `read_feed_entity()` in `FeedRepository` are no longer referenced
- **THEN** `entities/feed.cr` SHALL be deleted and `FeedRepository` cleaned up

### Requirement: Fix favicon_data propagation
The `favicon_data` field SHALL be correctly populated in all API responses that include it.

#### Scenario: Timeline items missing favicon_data
- **WHEN** `StoryService.get_timeline()` builds `TimelineItemResponse` objects
- **THEN** `favicon_data` SHALL be populated from the query results, not left as nil

#### Scenario: Cluster items hardcoded to nil
- **WHEN** `ClusterRepository` constructs `Entities::Story` objects for cluster responses
- **THEN** `favicon_data` SHALL be populated from the SQL query results

#### Scenario: Clustering service copies wrong field
- **WHEN** `ClusteringService.get_cluster_items_response()` sets `favicon_data = item.favicon`
- **THEN** it SHALL use the correct `favicon_data` field from the entity

#### Scenario: FeedResponse exposes internal paths
- **WHEN** `FeedResponse` DTO includes `favicon_data` with internal filesystem paths
- **THEN** the `favicon_data` field SHALL be removed from `FeedResponse` since frontend uses `favicon` for proxy endpoint

### Requirement: Remove dual DB init in FeedCache
`FeedCache` SHALL require a `DatabaseService` instance and SHALL NOT fall back to standalone `DB.open()`.

#### Scenario: FeedCache constructor simplification
- **WHEN** `FeedCache.new()` is called
- **THEN** the `db_service` parameter SHALL be non-optional `DatabaseService`
- **THEN** the standalone `DB.open()` fallback path SHALL be removed

#### Scenario: FeedCache load function
- **WHEN** `FeedCache.load_feed_cache()` is called
- **THEN** it SHALL pass `DatabaseService` without fallback logic

### Requirement: Resolve circular dependency
`DatabaseService` SHALL receive its configuration via explicit constructor parameter, not by reading `Application.initial_config`.

#### Scenario: DatabaseService initialization
- **WHEN** `DatabaseService` needs configuration
- **THEN** config SHALL be passed via `DatabaseService.new(config)` constructor
- **THEN** the forward declaration of `QuickHeadlines::Application` in `database_service.cr` SHALL be removed

#### Scenario: AppBootstrap creates DatabaseService
- **WHEN** `AppBootstrap` initializes the database
- **THEN** it SHALL create `DatabaseService.new(config)` directly and store the instance

### Requirement: Standardize transaction management
All database transactions SHALL use `@db.transaction { }` blocks. Manual `BEGIN`/`COMMIT`/`ROLLBACK` is prohibited.

#### Scenario: ClusteringStore transactions
- **WHEN** `ClusteringStore` uses manual `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`
- **THEN** it SHALL be converted to `@db.transaction { }` blocks

### Requirement: Clean up module-level state
Module-level mutable state that is only used within a single method SHALL be converted to local variables.

#### Scenario: Storage last_cache_cleanup
- **WHEN** `QuickHeadlines::Storage.last_cache_cleanup` is only accessed by `save_feed_cache()`
- **THEN** it SHALL be converted to a local variable within that method
