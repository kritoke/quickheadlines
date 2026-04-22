## ADDED Requirements

### Requirement: API routes SHALL be organized by route group
The API controller SHALL be split into focused modules under `src/controllers/routes/` grouped by API endpoint.

#### Scenario: Base controller module exists
- **WHEN** developer requires `./controllers/base_controller`
- **THEN** system provides shared controller logic including rate limiting

#### Scenario: Cluster routes module exists
- **WHEN** developer requires `./controllers/routes/cluster_routes`
- **THEN** system provides `/api/clusters` endpoint handlers

#### Scenario: Feed routes module exists
- **WHEN** developer requires `./controllers/routes/feed_routes`
- **THEN** system provides `/api/feeds/*` endpoint handlers

#### Scenario: Config routes module exists
- **WHEN** developer requires `./controllers/routes/config_routes`
- **THEN** system provides `/api/config/*` endpoint handlers

#### Scenario: Admin routes module exists
- **WHEN** developer requires `./controllers/routes/admin_routes`
- **THEN** system provides `/api/admin/*` endpoint handlers

#### Scenario: Item routes module exists
- **WHEN** developer requires `./controllers/routes/item_routes`
- **THEN** system provides `/api/items/*` endpoint handlers

### Requirement: Backward compatibility SHALL be maintained for API controller
Existing API endpoints SHALL function identically after refactoring.

#### Scenario: All API endpoints remain functional
- **WHEN** API controller is split into modules
- **THEN** all HTTP endpoints respond with identical behavior

#### Scenario: No API contract changes
- **WHEN** API routes are reorganized
- **THEN** request/response schemas remain unchanged
