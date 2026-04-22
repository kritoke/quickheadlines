## 1. Create FeedService Module

- [x] 1.1 Create `src/services/feed_service.cr` with `module QuickHeadlines::Services::FeedService`
- [x] 1.2 Implement `FeedService.build_feed_response(...)` — extract logic from `Api.feed_to_response()`
- [x] 1.3 Implement `FeedService.build_feed_more_response(...)` — extract logic from `FeedPaginationController.feed_more()` DTO construction
- [x] 1.4 Implement `FeedService.build_feeds_page(...)` — extract logic from `FeedsController.feeds()` that assembles `FeedsPageResponse` from feeds/tabs/software_releases
- [x] 1.5 Add `require "./services/feed_service"` to `application.cr`

## 2. Add DTO Methods to ClusteringService

- [x] 2.1 Add `ClusteringService#get_cluster_responses : ClustersResponse` — moves entity→DTO mapping from `ClusterController.clusters()`
- [x] 2.2 Add `ClusteringService#get_cluster_items_response(cluster_id : String, feed_cache : FeedCache) : ClusterItemsResponse` — moves DTO construction from `ClusterController.cluster_items()`

## 3. Refactor Controllers to Use Services

- [x] 3.1 Refactor `FeedsController.feeds()` — call `FeedService.build_feeds_page(...)`, remove all DTO construction
- [x] 3.2 Refactor `FeedPaginationController.feed_more()` — call `FeedService.build_feed_more_response(...)`, remove all DTO construction
- [x] 3.3 Refactor `ClusterController.clusters()` — call `clustering_service.get_cluster_responses`, remove entity mapping
- [x] 3.4 Refactor `ClusterController.cluster_items()` — call `clustering_service.get_cluster_items_response(...)`, remove DTO construction

## 4. Delete Api Module

- [x] 4.1 Remove `require "./api"` from `application.cr`
- [x] 4.2 Remove `require "../api"` from `src/services/story_service.cr`
- [x] 4.3 Delete `src/api.cr`
- [x] 4.4 Add `require "../dtos/api_responses"` to `story_service.cr` and `api_base_controller.cr`

## 5. Verification

- [x] 5.1 Run `just nix-build` — must succeed
- [x] 5.2 Run `nix develop . --command crystal spec` — all 177 tests pass
- [x] 5.3 Run `cd frontend && npm run test` — all 25 frontend tests pass
- [x] 5.4 Run `nix develop . --command crystal tool format --check src/` — formatted (feed_service.cr auto-formatted)
- [x] 5.5 Grep for `Api.feed_to_response` — zero results
- [x] 5.6 Grep for `ItemResponse.new` in controllers — zero results
- [x] 5.7 Grep for `FeedResponse.new` in controllers — zero results
