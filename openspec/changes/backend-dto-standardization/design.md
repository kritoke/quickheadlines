## Context

The QuickHeadlines backend uses Crystal 1.18.2 with the Athena web framework. API responses are built using `JSON::Serializable` DTOs that Athena auto-serializes. Over time, several controllers diverged from this pattern:

- `AdminController` manually builds JSON via hash literals for `status`/`version` endpoints and returns plain text for `cluster`/`admin` POST endpoints
- `HeaderColorController` uses hand-written JSON strings (`"{\"status\": \"ok\"}"`)
- 5 of 12 DTO classes live at the top level instead of under `QuickHeadlines::DTOs`
- The `Story` entity lacks `header_text_color`, `comment_url`, `commentary_url` fields that `TimelineItemResponse` already exposes
- `StoryResponse` DTO lacks `header_text_color`
- `FeedFetcher.build_cached_feed` passes 11 positional args to a 12-field `FeedData` record, silently dropping `header_theme_colors`
- `ErrorRenderer` implements `Athena::Framework::ErrorRendererInterface` but is never required, making it dead code
- Exception types are inconsistent: `HTTPException.new(503)` vs `ServiceUnavailable.new(...)` for the same semantic error

## Goals / Non-Goals

**Goals:**
- Every API endpoint that returns JSON SHALL use a typed `JSON::Serializable` DTO
- All DTOs SHALL live under the `QuickHeadlines::DTOs` namespace
- `Story` entity and `StoryResponse` DTO SHALL include all fields needed by both timeline and cluster APIs
- `header_theme_colors` SHALL be preserved through cache hit and error paths
- `ErrorRenderer` SHALL be active for all exception-based error responses
- Exception types SHALL be semantically consistent (ServiceUnavailable for 503, BadRequest for 400)

**Non-Goals:**
- Changing the existing API JSON shape (new fields are additive/nullable only)
- Modifying binary/static response endpoints (AssetController, ProxyController, StaticController)
- Adding new API endpoints
- Refactoring the DI pattern, duplicated logic, or architecture issues (separate changes)

## Decisions

### D1: Use named arguments for FeedData.new calls

`FeedData` is a 12-field record. Both `build_cached_feed` and `build_error_feed` use positional args and miss `header_theme_colors`. Switch to named args to prevent future positional mismatch bugs.

**Alternative considered**: Add a `#initialize` overload — rejected because Crystal records don't support custom initializers alongside the generated one cleanly.

### D2: Consolidate DTO namespace to QuickHeadlines::DTOs

Currently `StoryResponse`, `ClusterResponse`, `ClustersResponse`, `ConfigResponse` are under `QuickHeadlines::DTOs` while `TabResponse`, `TabsResponse`, `ItemResponse`, `FeedResponse`, `TimelineItemResponse`, `FeedsPageResponse`, `TimelinePageResponse`, `ClusterItemsResponse` are top-level. Move all under `QuickHeadlines::DTOs` and update all `require` and usage sites.

**Alternative considered**: Leave top-level DTOs as-is — rejected because it creates confusion about which types are DTOs vs domain objects.

### D3: Emit nulls for optional JSON fields

Use `@[JSON::Field(emit_null: true)]` on all nullable fields consistently. Some DTOs already do this (ItemResponse, FeedResponse, TimelineItemResponse) while others omit it (StoryResponse). Standardize to always emit nulls so frontend code can reliably check for field presence.

### D4: Wire ErrorRenderer in module.cr

Add `require "./errors/error_renderer"` to `module.cr` which is the central require point. This activates the custom JSON error format for all ATH exception-based errors.

**Alternative considered**: Wire in `application.cr` — rejected because `module.cr` is the canonical location for all requires.

### D5: Standardize exception types with a helper mapping

Rather than audit every controller manually, establish a convention:
- 400 → `ATH::Exception::BadRequest`
- 401 → `ATH::Exception::HTTPException.new(401, ...)`
- 403 → `ATH::Exception::HTTPException.new(403, ...)`
- 404 → `ATH::Exception::NotFound`
- 413 → `ATH::Exception::HTTPException.new(413, ...)`
- 429 → `ATH::Exception::HTTPException.new(429, ...)`
- 503 → `ATH::Exception::ServiceUnavailable`

Convert all violations found during implementation.

## Risks / Trade-offs

- **[DTO namespace move breaks internal references]** → All `require` statements and type references must be updated in a single pass. The compiler will catch any missed references.
- **[ErrorRenderer activation changes error response format]** → Frontend may currently expect Athena's default error format. Since ErrorRenderer returns `{"code": N, "message": "..."}` JSON, this is likely an improvement. Frontend error handling should be verified.
- **[New nullable fields on Story entity]** → All `Story.new` call sites must be updated. The compiler will catch missing args. Default values of `nil` prevent breaking existing behavior.
