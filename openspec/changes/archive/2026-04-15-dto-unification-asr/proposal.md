## Why

Controllers currently build DTOs directly from `FeedData`/`Item` models (feeds, feed_pagination) or use a procedural helper `Api.feed_to_response()`. This couples controller logic to internal data structures and breaks the Repository Pattern — if the DB schema or cache layer changes, every controller that touches those types must be updated. The DTO layer must be the exclusive boundary between backend data and the frontend.

## What Changes

- **Move all entity→DTO mapping into the service layer** so controllers become thin passthroughs that call a service method and return the resulting DTO
- **Delete `Api.feed_to_response()`** from `src/api.cr` — move its logic into `FeedService` module methods that return DTOs
- **Slim down controllers**: `FeedsController`, `FeedPaginationController`, and `ClusterController` must not construct DTOs — they call service methods that return ready-to-serialize DTOs
- **Keep `JSON::Serializable`** with snake_case keys — matches the existing frontend contract; zero frontend changes
- **Keep `ASR::Serializable` DTOs** (`StoryResponse`, `ClusterResponse`, `ConfigResponse`) as-is — they already work and serve the cluster/config endpoints
- **No file splitting of `api_responses.cr`** — DTOs stay where they are; the focus is on mapping ownership, not file reorganization

## Capabilities

### New Capabilities
- `dto-mapping-layer`: Defines the architectural contract that entity→DTO mapping happens exclusively in services, never in controllers. Controllers are thin passthroughs.

### Modified Capabilities
_(none — internal refactor, zero API behavior change)_

## Impact

- **Backend**: `src/api.cr` (deleted), new DTO-returning methods in a `FeedService` module, `FeedsController`, `FeedPaginationController`, `ClusterController` simplified
- **Frontend**: Zero changes — API contract (JSON keys, shapes) unchanged
- **Tests**: Existing specs must continue passing; may add service-level tests for DTO mapping
