## Why

The backend has drifted into inconsistent response patterns across controllers. Most API endpoints return typed `JSON::Serializable` DTOs that Athena auto-serializes, but several endpoints bypass this with manual hash `.to_json`, hand-written JSON strings, or plain text responses. The `Story` entity and `StoryResponse` DTO are missing fields that `TimelineItemResponse` already has, causing cluster API responses to return incomplete data. A `build_cached_feed` bug silently drops `header_theme_colors` on every cache hit. The custom `ErrorRenderer` is dead code (never required). These inconsistencies make the codebase harder to maintain and prone to subtle data loss bugs.

## What Changes

- Create typed `JSON::Serializable` DTOs for all endpoints currently returning manual JSON:
  - `AdminStatusResponse` for `GET /api/status`
  - `AdminVersionResponse` for `GET /api/version`
  - `AdminActionResponse` for `POST /api/cluster` and `POST /api/admin` (currently plain text)
  - `HeaderColorResponse` for `POST /api/header_color` (currently hand-written JSON strings)
- Consolidate all DTOs under `QuickHeadlines::DTOs` namespace (currently 5 are top-level, 4 are namespaced)
- Add missing fields to `Story` entity: `header_text_color`, `comment_url`, `commentary_url`
- Add `header_text_color` to `StoryResponse` DTO
- Fix `build_cached_feed` and `build_error_feed` in `FeedFetcher` to pass `header_theme_colors` through (data loss bug)
- Wire in `ErrorRenderer` via `require` in `module.cr`
- Standardize exception types: all 503s use `ServiceUnavailable`, all 400s use `BadRequest`
- Remove dead `display_header_color` and `display_header_text_color` methods from `FeedData` record
- Remove redundant `FeedFetcher.error_feed_data` static wrapper

## Capabilities

### New Capabilities
- `backend-dto-standardization`: Typed `JSON::Serializable` DTOs for all API endpoints, consistent namespace, complete field coverage

### Modified Capabilities

## Impact

- **Controllers modified**: `admin_controller.cr`, `header_color_controller.cr`
- **DTOs modified**: `story_dto.cr`, `cluster_dto.cr`, `api_responses.cr` (namespace + new types)
- **Entities modified**: `story.cr` (add fields)
- **Services modified**: `clustering_service.cr` (update `from_entity` mappings)
- **Fetcher modified**: `feed_fetcher.cr` (fix `header_theme_colors` data loss)
- **Wiring**: `module.cr` (require error_renderer)
- **No breaking API changes**: All existing JSON fields remain; new fields are additive (nullable where appropriate)
- **No new dependencies**: Uses only Crystal stdlib `JSON::Serializable` which is already in use
