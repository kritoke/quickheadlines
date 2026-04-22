## Why

The codebase has significant duplication in both Crystal backend and TypeScript frontend. Repeated patterns in entity mapping, API response handling, validation logic, and utility functions increase maintenance burden and risk of inconsistencies. Refactoring to follow DRY principles will improve maintainability and reduce bugs.

## What Changes

### Frontend (TypeScript/Svelte)
- Replace manual `JSON.parse(JSON.stringify())` clone with existing `deepClone` utility in `feedStore.svelte.ts`
- Extract common fetch pattern into generic `apiFetch` wrapper to eliminate duplicated error handling and toast notifications across API functions
- Review and consolidate overlapping type definitions

### Backend (Crystal)
- Consolidate duplicate `StoryResponse` DTO definitions (currently in both `src/dtos/story_dto.cr` and `src/api.cr`)
- Extract entity mapping logic in `StoryRepository` into reusable private `map_row_to_story` method
- Extract entity mapping logic in `FeedRepository` into reusable private helper methods
- Consolidate repetitive validation methods (`validate_limit`, `validate_offset`, `validate_days`) into single generic method
- Break up oversized API controller methods into smaller focused private methods
- Create helper for common response headers (Cache-Control, CORS)

## Capabilities

### New Capabilities
- `code-quality-standards`: Establish patterns for DRY code across frontend and backend

### Modified Capabilities
- None - this is purely a refactoring change with no behavioral changes

## Impact

### Affected Code
- `frontend/src/lib/stores/feedStore.svelte.ts` - Replace JSON clone with deepClone
- `frontend/src/lib/api.ts` - Add generic fetch wrapper
- `src/dtos/story_dto.cr` - Consolidate DTO definitions
- `src/api.cr` - Remove duplicate DTO, extract helpers
- `src/repositories/story_repository.cr` - Extract entity mapping
- `src/repositories/feed_repository.cr` - Extract entity mapping
- `src/controllers/api_controller.cr` - Consolidate validation, break up methods

### No Breaking Changes
This is a refactoring-only change with no changes to public APIs, data formats, or behavior.
