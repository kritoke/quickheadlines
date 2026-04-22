## Why

The QuickHeadlines backend has critical performance and architectural issues that degrade user experience and maintainability. The timeline endpoint suffers from N+1 query patterns causing slow page loads, database schema is duplicated across files risking drift, and magic numbers are scattered throughout the codebase. These issues compound technical debt and make the codebase harder to maintain.

## What Changes

### Priority 1: Critical (Performance & Correctness)
- Fix timeline N+1 query in `src/api.cr` - currently fetches cluster info per item in a loop
- Consolidate duplicate database schema definitions from `src/storage/database.cr` and `src/services/database_service.cr` into single source
- Centralize constants (`CONCURRENCY`, `CACHE_RETENTION_*`) into `src/constants.cr`

### Priority 2: Architecture (Maintainability)
- Refactor `src/application.cr` initialization blob (lines 44-173) into `src/services/app_bootstrap.cr` with proper separation
- Consolidate duplicate `TimelineItem` definitions in `src/models.cr` and `src/repositories/story_repository.cr`
- Add proper dependency injection for state management (reduce global `STATE` coupling)

### Priority 3: Reliability
- Add WebSocket heartbeat/ping-pong mechanism to prevent connection leaks
- Improve error handling - replace silent catches with proper logging
- Remove debug ENV flags from production code paths

## Capabilities

### New Capabilities
- `timeline-performance`: Optimized timeline queries with batched cluster info fetching
- `centralized-constants`: Single source for all magic numbers and configuration constants
- `app-bootstrap`: Structured application initialization with configurable background tasks
- `ws-heartbeat`: WebSocket connection health monitoring

### Modified Capabilities
- None - these are implementation refactors that don't change external behavior or requirements

## Impact

**Code Changes:**
- `src/api.cr` - Fix timeline query patterns
- `src/storage/database.cr` - Extract schema to shared module
- `src/services/database_service.cr` - Remove duplicate schema, keep migrations
- `src/constants.cr` - New file for centralized constants
- `src/services/app_bootstrap.cr` - New file for initialization logic
- `src/application.cr` - Refactor to use app_bootstrap
- `src/models.cr` - Consolidate TimelineItem definitions
- `src/repositories/story_repository.cr` - Remove duplicate TimelineItem
- `src/websocket.cr` - Add heartbeat mechanism

**Performance Impact:**
- Timeline endpoint: ~500x faster with 500 items (from N+1 to single query)
- Reduced database load across the board

**Breaking Changes:**
- None - all internal refactors maintain existing API contracts
