## Context

The QuickHeadlines Svelte 5 frontend currently suffers from architectural issues that impact maintainability and introduce potential bugs. The main page (`+page.svelte`) is 300+ lines with excessive state management, the theme system uses 6 separate color cache objects, and components are doing too much. This refactoring aims to establish clean architecture patterns while maintaining all current functionality.

### Current State
- Components hold both global and local state inconsistently
- Manual cache implementation with error-prone eviction logic
- Theme colors duplicated across 6+ data structures
- Code duplication between `+page.svelte` and `timeline/+page.svelte`
- Type safety gaps in theme handling

### Constraints
- Must maintain all existing functionality
- Must not break external APIs
- Svelte 5 runes must be used properly
- Must work with existing build system

### Stakeholders
- Frontend developers maintaining the codebase
- End users expecting reliable feed aggregation

## Goals / Non-Goals

**Goals:**
- Extract dedicated stores for feeds, timeline, and config state
- Consolidate theme configuration into single type-safe structure
- Split oversized components into focused, testable pieces
- Implement proper caching with automatic invalidation
- Create reusable utilities for common patterns
- Improve TypeScript coverage and type safety

**Non-Goals:**
- Rewrite backend Crystal API
- Add new user-facing features
- Change visual design or CSS approach
- Migrate to different frontend framework
- Add complex state management (Redux-style) - keep it simple with Svelte stores

## Decisions

### 1. State Management: Stores over Component State

**Decision:** Use Svelte 5 `$state` stores in dedicated `.svelte.ts` files instead of component-level state

**Rationale:** Eliminates duplication between pages, enables sharing state across components, improves testability

**Alternative Considered:** Using context API - rejected because stores are simpler for this use case

### 2. Theme Configuration: Single Source of Truth

**Decision:** Consolidate all theme colors into a single `themes` configuration object indexed by theme type

**Rationale:** Currently 6 separate cache objects must be updated when adding a theme; single structure ensures consistency

**Alternative Considered:** Runtime theme generation - rejected for performance reasons, static config is faster

### 3. Caching: Custom Store with TTL

**Decision:** Implement a simple cache store with time-to-live and automatic expiration

**Rationale:** Current manual eviction is error-prone; a proper cache with TTL is more maintainable

**Alternative Considered:** Using localForage or similar - rejected as overkill for this use case

### 4. Component Splitting: Logical Boundaries

**Decision:** Split based on functionality: FeedList, FeedCard, FeedHeader, ItemList, etc.

**Rationale:** Current FeedBox handles too many concerns; smaller components are easier to test and maintain

**Alternative Considered:** Keeping as-is with comments - rejected because it doesn't solve the underlying problem

### 5. Code Reuse: Composable Functions

**Decision:** Extract common patterns into composable `.ts` files in `frontend/src/lib/composables/`

**Rationale:** Reduces duplication of error handling, loading states, API calls across pages

**Alternative Considered:** Higher-order components - rejected as too complex for Svelte 5

## Risks / Trade-offs

**[Risk] Breaking changes to component APIs**
→ **Mitigation:** Maintain backward compatibility by using Svelte's prop defaults and migration path

**[Risk] Performance regression from over-abstraction**
→ **Mitigation:** Keep abstractions minimal, use `$derived` for computed values, avoid unnecessary indirection

**[Risk] Theme system regression**
→ **Mitigation:** Create comprehensive tests for all themes before and after refactoring

**[Risk] Cache invalidation bugs**
→ **Mitigation:** Use TTL-based expiration instead of manual eviction; add integration tests

**[Risk] State synchronization issues**
→ **Mitigation:** Use Svelte 5's reactivity correctly; avoid mixing stores with local state in same component

## Migration Plan

### Phase 1: Foundation
1. Create new store files (`feeds.svelte.ts`, `timeline.svelte.ts`, `config.svelte.ts`)
2. Implement unified theme configuration
3. Create cache store with TTL

### Phase 2: Component Extraction
1. Extract FeedHeader from FeedBox
2. Extract FeedCard from FeedBox  
3. Extract ItemList component
4. Create search modal composable

### Phase 3: Integration
1. Update +page.svelte to use new stores
2. Update timeline/+page.svelte to use new stores
3. Remove duplicate code

### Phase 4: Polish
1. Add TypeScript strict mode
2. Run tests and fix any regressions
3. Update documentation

### Rollback Strategy
- Git tags at each phase for easy rollback
- If critical bug found, revert to previous tag and fix before continuing

## Open Questions

1. **Should we use a state management library?** Currently using raw Svelte stores - consider if something like nanostores would help
2. **How to handle WebSocket state?** Currently embedded in components - should this be in a store?
3. **Test strategy?** Currently minimal frontend tests - should we add Vitest for stores?
