## ADDED Requirements

### Requirement: All JSON API endpoints use typed JSON::Serializable DTOs
Every controller action that returns JSON SHALL return a typed DTO class that includes `JSON::Serializable`. Controllers SHALL NOT manually construct JSON via hash literals, `.to_json`, or hand-written JSON strings.

#### Scenario: Admin status endpoint returns typed DTO
- **WHEN** `GET /api/status` is called
- **THEN** the response is a `QuickHeadlines::DTOs::AdminStatusResponse` object auto-serialized by Athena

#### Scenario: Admin version endpoint returns typed DTO
- **WHEN** `GET /api/version` is called
- **THEN** the response is a `QuickHeadlines::DTOs::AdminVersionResponse` object auto-serialized by Athena

#### Scenario: Admin POST endpoints return typed DTO
- **WHEN** `POST /api/cluster` or `POST /api/admin` is called successfully
- **THEN** the response is a `QuickHeadlines::DTOs::AdminActionResponse` object with `content-type: application/json`

#### Scenario: Header color endpoint returns typed DTO
- **WHEN** `POST /api/header_color` is called
- **THEN** the response is a `QuickHeadlines::DTOs::HeaderColorResponse` object auto-serialized by Athena

### Requirement: All DTOs live under QuickHeadlines::DTOs namespace
All DTO classes SHALL be defined within the `QuickHeadlines::DTOs` module. No DTO class SHALL exist at the top level.

#### Scenario: Top-level DTOs are moved to namespace
- **WHEN** the codebase is compiled
- **THEN** no DTO classes (`TabResponse`, `TabsResponse`, `ItemResponse`, `FeedResponse`, `TimelineItemResponse`, `FeedsPageResponse`, `TimelinePageResponse`, `ClusterItemsResponse`) exist at the top level

#### Scenario: All references updated
- **WHEN** the codebase is compiled
- **THEN** all controllers, services, and repositories reference DTOs via `QuickHeadlines::DTOs::` or appropriate alias

### Requirement: Story entity includes all fields needed by API responses
The `Story` entity SHALL include `header_text_color`, `comment_url`, and `commentary_url` fields to match the data available in `TimelineEntry`.

#### Scenario: Story entity has header_text_color
- **WHEN** a `Story` is constructed from database query results
- **THEN** `header_text_color` is populated when available from the query

#### Scenario: StoryResponse DTO includes header_text_color
- **WHEN** `StoryResponse.from_entity` is called
- **THEN** the resulting DTO includes `header_text_color`

### Requirement: header_theme_colors preserved through cache paths
`FeedFetcher.build_cached_feed` and `FeedFetcher.build_error_feed` SHALL pass `header_theme_colors` through to the `FeedData` record.

#### Scenario: Cached feed retains header_theme_colors
- **WHEN** a feed is loaded from cache
- **THEN** `header_theme_colors` from the cached object is included in the returned `FeedData`

#### Scenario: Error feed defaults header_theme_colors to nil
- **WHEN** a feed fails to fetch and an error `FeedData` is constructed
- **THEN** `header_theme_colors` is explicitly set to `nil` via named argument

### Requirement: ErrorRenderer is active for all exception-based error responses
The custom `ErrorRenderer` SHALL be required in `module.cr` so Athena uses it for all `ATH::Exception` based error responses.

#### Scenario: ErrorRenderer wired in
- **WHEN** an `ATH::Exception` is raised in any controller
- **THEN** the response uses the custom `ErrorRenderer` format: `{"code": N, "message": "..."}`

### Requirement: Exception types are semantically consistent
All controllers SHALL use the correct Athena exception class for each HTTP status code. 503 errors SHALL use `ServiceUnavailable`. 400 errors SHALL use `BadRequest`.

#### Scenario: ServiceUnavailable for 503
- **WHEN** a controller needs to return HTTP 503
- **THEN** it raises `ATH::Exception::ServiceUnavailable`

#### Scenario: BadRequest for 400
- **WHEN** a controller needs to return HTTP 400 due to invalid input
- **THEN** it raises `ATH::Exception::BadRequest`

### Requirement: Optional DTO fields use emit_null annotation
All nullable fields on DTOs SHALL use `@[JSON::Field(emit_null: true)]` so the frontend can reliably check for field presence.

#### Scenario: StoryResponse emits null fields
- **WHEN** a `StoryResponse` with nil `header_color` is serialized
- **THEN** the JSON output includes `"header_color": null`

### Requirement: Dead code removed
The `display_header_color` and `display_header_text_color` methods on `FeedData` SHALL be removed. The `FeedFetcher.error_feed_data` static wrapper SHALL be removed; callers SHALL use `FeedFetcher.instance.build_error_feed` directly.

#### Scenario: FeedData has no display methods
- **WHEN** the `FeedData` record is defined
- **THEN** it does not contain `display_header_color` or `display_header_text_color` methods

#### Scenario: FeedFetcher has no static error_feed_data
- **WHEN** `FeedFetcher` is defined
- **THEN** it does not contain a `self.error_feed_data` class method
