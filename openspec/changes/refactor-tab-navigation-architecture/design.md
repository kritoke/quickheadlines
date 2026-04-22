## Context

The current implementation uses multiple state sources for tab management: URL parameters, `feedState.activeTab`, and `navigationStore.feedsTab`. This creates a complex web of bidirectional data flow where components attempt to synchronize with each other, leading to race conditions, infinite loops in effect handlers, and inconsistent behavior. The AppHeader component contains navigation logic mixed with presentation, and both feed/timeline pages duplicate state management logic.

The application uses Svelte 5 with runes (`$state`, `$derived`, `$effect`) and should leverage the `$page` store for reactive URL access. However, improper effect usage causes components to re-execute on every render instead of only when relevant dependencies change.

## Goals / Non-Goals

**Goals:**
- Establish URL parameters as the single source of truth for tab state
- Eliminate all intermediate state stores (`feedState.activeTab`, `navigationStore.feedsTab`)
- Create centralized navigation service for consistent view switching
- Make AppHeader purely presentational with no state or logic
- Standardize page initialization patterns using `onMount` + guarded `$effect`
- Eliminate race conditions, infinite loops, and excessive API calls
- Reduce code complexity and improve maintainability

**Non-Goals:**
- Changing URL structure or routing paths
- Modifying backend API endpoints or data models  
- Adding new features beyond architectural cleanup
- Changing existing UI/UX behavior (only fixing broken behavior)

## Decisions

### 1. URL as Single Source of Truth
**Decision**: Remove all intermediate tab state stores and rely exclusively on `$page.url.searchParams.get('tab')`.
**Rationale**: Multiple state sources create synchronization complexity and race conditions. URL parameters are inherently shared across all pages and provide natural persistence. This eliminates ~50% of state management code.

### 2. Centralized Navigation Service
**Decision**: Create `NavigationService` class to handle all view switching logic.
**Rationale**: Scattered navigation logic in AppHeader and page components leads to inconsistencies. Centralizing this ensures uniform URL construction and eliminates duplication.

### 3. Pure Presentational AppHeader
**Decision**: AppHeader becomes stateless presentational component receiving only props.
**Rationale**: Mixing navigation logic with presentation violates separation of concerns. Presentational components are easier to test, debug, and reason about.

### 4. Standardized Page Patterns
**Decision**: Both pages use identical pattern: `onMount` for initialization, separate `$effect` for URL changes with proper guards.
**Rationale**: Inconsistent initialization patterns (`onMount` vs `$effect`) cause timing issues. Standardization ensures predictable behavior and reduces cognitive load.

### 5. Guard Conditions for Effects
**Decision**: All `$effect` handlers include boolean flags to prevent infinite loops.
**Rationale**: Without guards, effects can trigger themselves during state updates, causing infinite renders and API calls.

## Risks / Trade-offs

**[Risk] Breaking existing deep links** → **Mitigation**: Maintain identical URL structure (`/?tab=X`, `/timeline?tab=X`) to preserve all existing links.

**[Risk] Increased coupling to $page store** → **Mitigation**: `NavigationService` abstracts `$page` usage, providing clean interface for components.

**[Risk] Regression in edge cases** → **Mitigation**: Comprehensive testing of all navigation scenarios before deployment.

**[Risk] Performance impact from repeated URL reads** → **Mitigation**: Svelte's `$page` store is optimized and cached; minimal performance impact expected.