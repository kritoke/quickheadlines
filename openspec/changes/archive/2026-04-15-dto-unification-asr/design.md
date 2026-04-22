## Context

The backend has a mixed pattern for entity→DTO mapping:

| Endpoint | Current Mapping Location | Pattern |
|----------|------------------------|---------|
| `/api/timeline` | `StoryService.get_timeline()` | Service returns DTOs ✓ |
| `/api/clusters` | `ClusterController.clusters()` | Controller maps entities to DTOs ✗ |
| `/api/clusters/{id}/items` | `ClusterController.cluster_items()` | Controller builds DTOs from DB rows ✗ |
| `/api/feeds` | `FeedsController.feeds()` via `Api.feed_to_response()` | Procedural helper builds DTOs ✗ |
| `/api/feed_more` | `FeedPaginationController.feed_more()` | Controller manually builds DTOs ✗ |
| `/api/tabs` | `TabsController.tabs()` | Controller builds DTOs from config ✗ |
| `/api/config` | `ConfigController.config()` | Controller builds DTO from config ✓ (trivial) |

`StoryService` is the only service that follows the correct pattern. All others either have DTO construction in controllers or delegate to a procedural `Api.feed_to_response()` function.

The DTOs themselves are split between `JSON::Serializable` (api_responses.cr — 8 DTOs) and `ASR::Serializable` (story_dto.cr, cluster_dto.cr, config_dto.cr — 4 DTOs). The frontend consumes snake_case keys from the JSON::S DTOs and camelCase from the ASR DTOs.

## Goals / Non-Goals

**Goals:**
- Entity→DTO mapping lives exclusively in the service layer
- Controllers are thin: call service, return DTO, done
- `Api.feed_to_response()` is deleted and its logic absorbed into a proper service
- Zero behavioral change to API responses (same JSON shapes, same keys)
- `StoryService` pattern (service returns DTOs) is the template for all others

**Non-Goals:**
- Unifying JSON::Serializable vs ASR::Serializable (separate future change)
- Changing JSON key casing (snake_case vs camelCase)
- Splitting `api_responses.cr` into multiple files
- Refactoring the frontend
- Changing the WebSocket event format
- Modifying the `TimelineController` (already correct — uses `StoryService`)
- Modifying `ConfigController` (trivially correct — 3 fields from config)

## Decisions

### 1. Mapping lives in service modules, not controllers

**Decision:** Create a `FeedService` module (module-level methods, matching `StoryService` pattern) that accepts dependencies and returns DTOs.

**Rationale:** `StoryService` already uses this pattern successfully. Controllers call `StoryService.get_timeline(repo, limit, ...)` and get back `TimelineResult` containing DTOs. We replicate this for feeds and clusters.

**Alternative considered:** Adding DTO methods to repositories. Rejected because feed data comes from `FeedCache` (in-memory cache), not from `FeedRepository` (DB). Repositories own DB queries; services own orchestration across data sources (cache + DB + config).

### 2. FeedService as module-level methods (not a class)

**Decision:** `module QuickHeadlines::Services::FeedService` with `def self.build_feed_response(...)` style methods.

**Rationale:** Matches `StoryService` convention. No state needed — all data comes from parameters. Avoids DI complexity.

### 3. FeedService methods

| Method | Signature | Returns | Replaces |
|--------|-----------|---------|----------|
| `build_feed_response` | `(FeedData, tab_name, total_count, limit, FeedCache) → FeedResponse` | Single feed DTO | `Api.feed_to_response()` |
| `build_feeds_page` | `(feeds, tabs, software_releases, active_tab, clustering, updated_at, FeedCache, item_limit) → FeedsPageResponse` | Full page DTO | `FeedsController.feeds()` body |
| `build_feed_more_response` | `(FeedData, tab_name, offset, limit, FeedCache, item_count) → FeedResponse` | Paginated feed DTO | `FeedPaginationController.feed_more()` DTO construction |

### 4. ClusterService methods

| Method | Signature | Returns | Replaces |
|--------|-----------|---------|----------|
| `get_cluster_responses` | `(ClusteringService, db_service) → ClustersResponse` | Cluster list DTOs | `ClusterController.clusters()` mapping |
| `get_cluster_items_response` | `(cluster_id, feed_cache) → ClusterItemsResponse` | Cluster items DTO | `ClusterController.cluster_items()` construction |

These go into the existing `ClusteringService` class (or a new `ClusterDtoService` module if that's cleaner). Given `ClusteringService` already exists and is injected, adding DTO-returning methods there avoids a new class.

### 5. Delete `src/api.cr` entirely

**Decision:** Remove `Api.feed_to_response()` and the `require "./api"` from `application.cr`.

**Rationale:** Its logic moves into `FeedService.build_feed_response()`. No other code references `Api`.

## Risks / Trade-offs

- **[Risk] Behavior divergence during migration** → Each method is a direct extraction of existing controller code. The JSON output is byte-identical before and after. Verified by existing 177 Crystal specs.
- **[Risk] FeedService needs FeedCache parameter** → FeedCache is already available in controllers via `@feed_cache`. Controllers pass it to the service method. No new coupling.
- **[Trade-off] Mixed serialization remains** → JSON::S and ASR coexist after this change. Acceptable — unifying serializers is a separate concern with its own change.
- **[Trade-off] TabsController still builds DTOs** → TabResponse/TabResponse construction is trivial (1 field from config). Not worth extracting to a service. If desired later, it fits into FeedService.
