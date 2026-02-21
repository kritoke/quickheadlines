## Why

The current codebase has architecture violations where Controllers directly access the database and perform raw SQL queries, bypassing the Service and Repository layers. Additionally, the Svelte frontend lacks semantic `data-name` attributes needed for AI agent interaction. This refactor establishes proper layered architecture and meets the semantic metadata requirement.

## What Changes

### Backend
1. **Implement Repository Layer** - Extract all SQL from Controllers into proper Repository classes
2. **Implement Service Layer** - Create FeedService and StoryService with business logic
3. **Refactor FeedCache** - Strip SQL, keep only in-memory caching
4. **Refactor ApiController** - Remove all raw SQL, use Services exclusively

### Frontend
5. **Add Semantic Metadata** - Add `data-name` attributes to all primary layout and interactive elements

## Capabilities

### New Capabilities
- `repository-pattern`: Full implementation of Repository pattern for Feed and Story entities
- `feed-service`: Business logic layer for feed operations (ingestion, subscription management)
- `story-service`: Business logic layer for story operations (persistence, deduplication, clustering)
- `semantic-metadata`: Semantic `data-name` attributes for AI agent DOM interaction

### Modified Capabilities
- None - this is a pure refactor with no behavioral changes

## Impact

### Affected Code
- `src/repositories/` - New implementations for FeedRepository, StoryRepository, ClusterRepository
- `src/services/` - New FeedService, StoryService; refactored ClusterService
- `src/controllers/api_controller.cr` - Removed raw SQL methods
- `src/storage/feed_cache.cr` - Stripped of SQL, pure cache
- `frontend/src/lib/components/*.svelte` - Added data-name attributes

### Dependencies
- No new dependencies required

### Breaking Changes
- None - this is internal refactoring only, API contracts remain unchanged
