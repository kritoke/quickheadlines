## 1. Foundation - Time Format & Error Handling

- [x] 1.1 Add `DB_TIME_FORMAT = "%Y-%m-%d %H:%M:%S"` to `src/constants.cr`
- [x] 1.2 Replace time format literal in `src/repositories/feed_repository.cr` (8 occurrences)
- [x] 1.3 Replace time format literal in `src/repositories/story_repository.cr` (3 occurrences)
- [x] 1.4 Replace time format literal in `src/repositories/cluster_repository.cr` (1 occurrence)
- [x] 1.5 Replace time format literal in `src/services/clustering_service.cr` (1 occurrence)
- [x] 1.6 Replace time format literal in `src/services/database_service.cr` (1 occurrence)
- [ ] 1.7 Add typed `rescue` to `src/config/loader.cr` (line 84)
- [ ] 1.8 Add typed `rescue` to `src/repositories/feed_repository.cr` (line 68)
- [ ] 1.9 Add typed `rescue` to `src/storage/database.cr` (line 125)

## 2. Module Naming - Rename `Quickheadlines` → `QuickHeadlines`

- [x] 2.1 Rename module in `src/controllers/api_controller.cr`
- [x] 2.2 Rename module in `src/services/feed_service.cr`
- [x] 2.3 Rename module in `src/services/story_service.cr`
- [x] 2.4 Rename module in `src/services/clustering_service.cr`
- [x] 2.5 Rename module in `src/services/heat_map_service.cr`
- [x] 2.6 Rename module in `src/services/feed_state.cr`
- [x] 2.7 Rename module in `src/repositories/feed_repository.cr`
- [x] 2.8 Rename module in `src/repositories/story_repository.cr`
- [x] 2.9 Rename module in `src/repositories/cluster_repository.cr`
- [x] 2.10 Rename module in `src/repositories/heat_map_repository.cr`
- [x] 2.11 Rename module in `src/entities/story.cr`
- [x] 2.12 Rename module in `src/entities/feed.cr`
- [x] 2.13 Rename module in `src/entities/cluster.cr`
- [x] 2.14 Rename module in `src/errors/error_renderer.cr`
- [x] 2.15 Rename module in `src/dtos/story_dto.cr`
- [x] 2.16 Rename module in `src/dtos/config_dto.cr`
- [x] 2.17 Rename module in `src/dtos/cluster_dto.cr`
- [x] 2.18 Rename module in `src/dtos/feed_dto.cr`
- [x] 2.19 Rename module in `src/dtos/status_dto.cr`
- [x] 2.20 Rename module in `src/dtos/rate_limit_stats_dto.cr`
- [x] 2.21 Rename module in `src/events/story_fetched_event.cr`
- [x] 2.22 Rename module in `src/listeners/heat_map_listener.cr`

## 3. Free Functions → Module Methods

- [ ] 3.1 Convert `src/config/loader.cr` free functions to `QuickHeadlines::ConfigLoader` module methods
- [ ] 3.2 Convert `src/config/validator.cr` free functions to `QuickHeadlines::ConfigValidator` module methods
- [ ] 3.3 Convert `src/storage/feed_cache.cr` free functions to `QuickHeadlines::FeedCacheManager` module methods
- [ ] 3.4 Convert `src/fetcher/feed_fetcher.cr` free functions to `QuickHeadlines::FeedFetcher` class methods
- [ ] 3.5 Convert `src/fetcher/refresh_loop.cr` free functions to `QuickHeadlines::RefreshLoop` module methods

## 4. Logging Modernization

- [ ] 4.1 Replace `STDERR.puts` in `src/application.cr` with `Log` calls
- [ ] 4.2 Replace `STDERR.puts` in `src/config/loader.cr` with `Log` calls
- [ ] 4.3 Replace `STDERR.puts` in `src/config/validator.cr` with `Log` calls
- [ ] 4.4 Replace `STDERR.puts` in `src/storage/database.cr` with `Log` calls
- [ ] 4.5 Replace `STDERR.puts` in `src/storage/feed_cache.cr` with `Log` calls
- [ ] 4.6 Replace `STDERR.puts` in `src/fetcher/feed_fetcher.cr` with `Log` calls
- [ ] 4.7 Replace `STDERR.puts` in `src/fetcher/refresh_loop.cr` with `Log` calls
- [ ] 4.8 Replace `STDERR.puts` in `src/services/database_service.cr` with `Log` calls
- [ ] 4.9 Replace `STDERR.puts` in `src/services/clustering_service.cr` with `Log` calls
- [ ] 4.10 Replace `STDERR.puts` in `src/services/app_bootstrap.cr` with `Log` calls
- [ ] 4.11 Replace `STDERR.puts` in `src/controllers/api_controller.cr` with `Log` calls
- [ ] 4.12 Add `Log` backend configuration in `src/application.cr`

## 5. Consolidate Database Schema Initialization

- [ ] 5.1 Remove `create_schema` call from `src/storage/feed_cache.cr` constructor
- [ ] 5.2 Remove duplicate `create_schema` from `src/services/database_service.cr`
- [ ] 5.3 Ensure `DatabaseService` is the sole schema initialization point
- [ ] 5.4 Verify schema migrations run only once on startup

## 6. Dependency Injection - Register Services & Remove Singletons

- [ ] 6.1 Register `QuickHeadlines::Services::FeedService` with `@[ADI::Register]`
- [ ] 6.2 Register `QuickHeadlines::Services::StoryService` with `@[ADI::Register]`
- [ ] 6.3 Register `QuickHeadlines::Services::ClusteringService` with `@[ADI::Register]`
- [ ] 6.4 Register `QuickHeadlines::Repositories::FeedRepository` with `@[ADI::Register]`
- [ ] 6.5 Register `QuickHeadlines::Repositories::StoryRepository` with `@[ADI::Register]`
- [ ] 6.6 Register `QuickHeadlines::Repositories::ClusterRepository` with `@[ADI::Register]`
- [ ] 6.7 Remove `@@instance` from `FeedCache` class
- [ ] 6.8 Remove `@@instance` from `DatabaseService` class
- [ ] 6.9 Remove `@@instance` from `FeedFetcher` class
- [ ] 6.10 Remove `FEED_CACHE` global constant
- [ ] 6.11 Remove `SEM` global channel constant (move to DI-managed service)
- [ ] 6.12 Remove `clustering_service` global function
- [ ] 6.13 Update `ApiController` to accept injected services via constructor

## 7. Controller Split - Extract from ApiController

- [ ] 7.1 Create `src/controllers/assets_controller.cr` for static asset serving
- [ ] 7.2 Create `src/controllers/proxy_controller.cr` for image proxy
- [ ] 7.3 Create `src/controllers/admin_controller.cr` for admin actions
- [ ] 7.4 Create `src/controllers/cluster_controller.cr` for clustering endpoints
- [ ] 7.5 Create `src/controllers/timeline_controller.cr` for timeline endpoint
- [ ] 7.6 Rename remaining `ApiController` → `FeedsController`
- [ ] 7.7 Remove old `/api/status` endpoint or consolidate
- [ ] 7.8 Verify all routes work unchanged

## 8. Simplify Utils.private_host?

- [ ] 8.1 Refactor `src/utils.cr` `private_host?` to use `IPAddress.private?` or compact subnet check

## 9. Entry Point Cleanup

- [ ] 9.1 Remove duplicate initialization from `src/application.cr`
- [ ] 9.2 Ensure single `ATH.run` call in `src/quickheadlines.cr` only
- [ ] 9.3 Verify build works with `just nix-build`

## 10. Verification

- [ ] 10.1 Run `nix develop . --command crystal spec` - all tests pass
- [ ] 10.2 Run `just nix-build` - builds successfully
- [ ] 10.3 Run `nix develop . --command ameba --fix` - no lint errors
- [ ] 10.4 Verify no `@@instance` patterns remain in codebase
- [ ] 10.5 Verify all modules use `QuickHeadlines` (not `Quickheadlines`)
- [ ] 10.6 Verify no `STDERR.puts` calls remain (only `Log` calls)
