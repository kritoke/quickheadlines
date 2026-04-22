## Context

The codebase has grown organically with repeated patterns across frontend and backend:
- **Frontend**: Duplicate fetch/error handling, JSON clone instead of existing utility
- **Backend**: Duplicate entity mapping in repositories, duplicate DTO definitions, oversized controller methods

This refactoring aims to consolidate these patterns without changing any public behavior.

## Goals / Non-Goals

**Goals:**
- Replace JSON clone in feedStore with existing deepClone utility
- Create generic API fetch wrapper to eliminate repeated error handling
- Consolidate duplicate StoryResponse DTO definitions
- Extract entity mapping logic into reusable methods in repositories
- Consolidate validation logic into single generic method
- Break up oversized controller methods into focused helpers

**Non-Goals:**
- No changes to public APIs or data formats
- No new features or capabilities
- No database schema changes
- No changes to test coverage (tests should still pass)

## Decisions

### 1. Generic API Fetch Wrapper
**Decision**: Create `apiFetch<T>` helper in `frontend/src/lib/api.ts`
**Rationale**: All API functions follow same pattern: fetch → check ok → json → error handling. Centralizing this eliminates ~50 lines of duplication.
**Alternative considered**: Use existing library like axios - rejected because native fetch is sufficient and adds dependency

### 2. DTO Consolidation
**Decision**: Keep `StoryResponse` in `src/dtos/story_dto.cr` and remove from `src/api.cr`
**Rationale**: `dtos/` folder is the canonical location for data transfer objects. `src/api.cr` should only contain API routing logic.
**Alternative considered**: Move all to api.cr - rejected, dto folder provides better organization

### 3. Repository Entity Mapping
**Decision**: Extract private `map_row_to_story` and similar methods in each repository
**Rationale**: Eliminates ~60 lines of duplication while maintaining single responsibility. Each repository handles its own mapping logic.
**Alternative considered**: Use ORM/macro - rejected, Crystal's DB mapping is explicit and this approach is more readable

### 4. Validation Consolidation
**Decision**: Create single `validate_int` method with bounds parameters
**Rationale**: `validate_limit`, `validate_offset`, `validate_days` all follow same pattern of parsing int and applying bounds.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Accidentally breaking tests | Run full test suite after each change |
| Introducing bugs in refactored code | Keep changes atomic and verify incrementally |
| Breaking existing API contracts | No changes to response formats, only internal structure |

## Migration Plan

1. Work on frontend changes first (lower risk, isolated)
2. Then Crystal backend changes
3. Run full test suite after each file change
4. Build with `just nix-build` before considering complete

No rollback needed - changes are purely internal refactoring with no behavioral changes.
