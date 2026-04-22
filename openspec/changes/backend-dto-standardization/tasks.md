## 1. Entity & DTO Field Completeness

- [x] 1.1 Add `header_text_color`, `comment_url`, `commentary_url` fields to `Story` entity (src/entities/story.cr)
- [x] 1.2 Add `header_text_color : String?` to `StoryResponse` DTO with `@[JSON::Field(emit_null: true)]` (src/dtos/story_dto.cr)
- [x] 1.3 Update `StoryResponse.from_entity` to map `header_text_color`
- [x] 1.4 Update `ClusterRepository` to pass `header_text_color`, `comment_url`, `commentary_url` when building `Story` entities
- [x] 1.5 Add `emit_null: true` to all nullable fields on `StoryResponse` that lack it

## 2. FeedData Data Loss Fix

- [x] 2.1 Convert `build_cached_feed` positional `FeedData.new` to named arguments, include `header_theme_colors`
- [x] 2.2 Convert `build_error_feed` positional `FeedData.new` to named arguments, include `header_theme_colors: nil`

## 3. New DTOs for Manual-JSON Endpoints

- [x] 3.1 Create `AdminStatusResponse` DTO in api_responses.cr (fields: version, uptime, feeds_count, items_count, refreshing, active_jobs, websocket_connections, last_refresh, memory_usage_mb)
- [x] 3.2 Create `AdminVersionResponse` DTO in api_responses.cr (fields: version, crystal_version, build_date)
- [x] 3.3 Create `AdminActionResponse` DTO in api_responses.cr (fields: status, message)
- [x] 3.4 Create `HeaderColorResponse` DTO in api_responses.cr (fields: status)

## 4. Controller Standardization

- [x] 4.1 Update `AdminController#status` to return `AdminStatusResponse` DTO instead of manual hash `.to_json`
- [x] 4.2 Update `AdminController#version` to return `AdminVersionResponse` DTO instead of manual hash `.to_json`
- [x] 4.3 Update `AdminController#cluster` to return `AdminActionResponse` DTO instead of plain text `ATH::Response`
- [x] 4.4 Update `AdminController#admin` to return `AdminActionResponse` DTO instead of plain text `ATH::Response`
- [x] 4.5 Update `HeaderColorController#save_header_color` to return `HeaderColorResponse` DTO instead of hand-written JSON strings

## 5. DTO Namespace Consolidation

- [x] 5.1 Move top-level DTOs (`TabResponse`, `TabsResponse`, `ItemResponse`, `FeedResponse`, `TimelineItemResponse`, `FeedsPageResponse`, `TimelinePageResponse`, `ClusterItemsResponse`) into `QuickHeadlines::DTOs` module in api_responses.cr
- [x] 5.2 Update all `require` and type references in controllers (feeds, timeline, config, tabs, feed_pagination, cluster)
- [x] 5.3 Update all `require` and type references in services (feed_service, story_service, clustering_service)

## 6. Error Handling Standardization

- [x] 6.1 Add `require "./errors/error_renderer"` to module.cr — SKIPPED: Athena 0.21.x does not have `ErrorRendererInterface`, ErrorRenderer remains dead code
- [x] 6.2 Convert `HeaderColorController` 503 from `HTTPException.new(503)` to `ServiceUnavailable`
- [x] 6.3 Audit and fix any remaining `HTTPException.new(503)` across all controllers

## 7. Dead Code Removal

- [x] 7.1 Remove `display_header_color` and `display_header_text_color` methods from `FeedData` in models.cr
- [x] 7.2 Remove `FeedFetcher.error_feed_data` static wrapper, update callers in refresh_loop.cr to use `FeedFetcher.instance.build_error_feed`

## 8. Verification

- [x] 8.1 Run `just nix-build` and verify compilation succeeds
- [x] 8.2 Run `nix develop . --command crystal spec` and verify tests pass
