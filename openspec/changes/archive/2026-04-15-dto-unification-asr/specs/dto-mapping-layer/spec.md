## ADDED Requirements

### Requirement: Controllers MUST NOT construct DTOs
Controllers SHALL NOT contain logic that maps entities, models, or database rows into DTO structs. Controllers SHALL call service methods that return ready-to-serialize DTOs.

#### Scenario: FeedsController returns DTOs from service
- **WHEN** `FeedsController.feeds()` is called
- **THEN** it calls a `FeedService` method that returns `FeedsPageResponse`
- **AND** the controller returns the DTO without modifying its fields

#### Scenario: FeedPaginationController returns DTO from service
- **WHEN** `FeedPaginationController.feed_more()` is called
- **THEN** it calls a `FeedService` method that returns `FeedResponse`
- **AND** the controller returns the DTO without modifying its fields

#### Scenario: ClusterController returns DTOs from service
- **WHEN** `ClusterController.clusters()` is called
- **THEN** it calls a service method that returns `ClustersResponse`
- **WHEN** `ClusterController.cluster_items()` is called
- **THEN** it calls a service method that returns `ClusterItemsResponse`

### Requirement: Service layer owns entity-to-DTO mapping
All mapping from internal data types (`FeedData`, `Item`, `Entities::Story`, `Entities::Cluster`, DB rows) to DTO types (`FeedResponse`, `ItemResponse`, `TimelineItemResponse`, `ClusterResponse`, `StoryResponse`, `ClusterItemsResponse`) SHALL happen within service modules.

#### Scenario: FeedService maps FeedData to FeedResponse
- **WHEN** `FeedService.build_feed_response()` is called with a `FeedData` model and cache context
- **THEN** it returns a `FeedResponse` DTO with all fields populated (header colors, theme, items, favicon)
- **AND** the JSON output is identical to what `Api.feed_to_response()` produced

#### Scenario: FeedService maps FeedData array to FeedsPageResponse
- **WHEN** `FeedService.build_feeds_page()` is called with feeds, tabs, and configuration
- **THEN** it returns a `FeedsPageResponse` DTO containing `TabResponse[]`, `FeedResponse[]`, and metadata

### Requirement: Api.feed_to_response procedural helper MUST be removed
The `Api` module in `src/api.cr` and its `feed_to_response()` method SHALL be deleted. Its logic SHALL move into `FeedService` module methods.

#### Scenario: api.cr is deleted
- **WHEN** the refactoring is complete
- **THEN** `src/api.cr` does not exist
- **AND** `application.cr` no longer contains `require "./api"`
- **AND** all 177 Crystal specs pass

### Requirement: Zero API contract changes
The JSON shape, key names, and values returned by all API endpoints SHALL remain identical before and after this refactoring. No frontend changes are required.

#### Scenario: /api/feeds response unchanged
- **WHEN** a GET request is made to `/api/feeds?tab=all`
- **THEN** the response JSON has the same keys, types, and structure as before the refactoring

#### Scenario: /api/feed_more response unchanged
- **WHEN** a GET request is made to `/api/feed_more?url=<url>&offset=0&limit=10`
- **THEN** the response JSON matches the pre-refactoring output

#### Scenario: /api/clusters response unchanged
- **WHEN** a GET request is made to `/api/clusters`
- **THEN** the response JSON matches the pre-refactoring output

### Requirement: StoryService pattern is the template
The existing `StoryService.get_timeline()` method demonstrates the correct pattern: it accepts a repository, queries data, maps to `TimelineItemResponse` DTOs, and returns a `TimelineResult` containing DTOs. All new service methods SHALL follow this pattern.

#### Scenario: FeedService follows StoryService conventions
- **WHEN** `FeedService` is implemented
- **THEN** it is a `module QuickHeadlines::Services::FeedService` with `def self.*` methods
- **AND** it accepts dependencies as parameters (not singletons)
- **AND** it returns DTO types, not internal models
