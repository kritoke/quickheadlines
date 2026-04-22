## Context

The current implementation suffers from multiple conflicting sources of truth for tab state:
- URL parameters (authoritative but not always respected)
- `feedState.activeTab` (frontend store state)
- `navigationStore.feedsTab` (separate navigation state)
- Timeline page local derived state

This complexity causes race conditions, reactivity issues in Svelte 5, and inconsistent behavior when navigating between feed view (`/?tab=X`) and timeline view (`/timeline?tab=X`). Special characters in tab names (like "&" in "AI & ML") exacerbate the problem due to URL encoding/decoding complexities.

The application uses Svelte 5 with runes (`$state`, `$derived`, `$effect`) and should leverage the `$page` store for reactive URL parameter access.

## Goals / Non-Goals

**Goals:**
- Eliminate all secondary state sources and use ONLY URL parameters as single source of truth
- Ensure reliable tab persistence when switching between feed and timeline views
- Fix timeline blank issues for tabs with special characters
- Simplify codebase by removing redundant state synchronization logic
- Maintain backward compatibility with existing URL structure

**Non-Goals:**
- Changing the tab naming convention or data model
- Modifying backend API endpoints or database schema
- Adding new features beyond fixing the core navigation issue

## Decisions

### 1. Single Source of Truth: URL Parameters
**Decision**: Use only `$page.url.searchParams.get('tab')` throughout the application.
**Rationale**: URL parameters are inherently shared across all pages and provide a consistent, authoritative source of truth. This eliminates the need for complex state synchronization between components.

### 2. AppHeader Navigation Logic
**Decision**: Remove all tab-related props from AppHeader and have it read directly from `$page` store.
**Rationale**: Current implementation passes complex objects (`viewLink`) which can capture stale values. Direct `$page` store access ensures real-time reactivity.

### 3. Replace onMount with $effect
**Decision**: Timeline page will use `$effect` instead of `onMount` for initial load and tab change handling.
**Rationale**: `onMount` only runs once and doesn't respond to URL changes during navigation. `$effect` provides proper reactivity to parameter changes.

### 4. Robust Error and Loading States
**Decision**: Add explicit handling for empty timeline scenarios with user-friendly messages.
**Rationale**: Currently, empty timelines show nothing, creating confusion. Proper feedback improves user experience.

### 5. Minimal Backend Changes
**Decision**: Keep backend unchanged; fix is entirely frontend-focused.
**Rationale**: The backend API works correctly when given properly encoded parameters. The issue is in frontend URL construction and state management.

## Risks / Trade-offs

**[Risk] Breaking existing deep links** → **Mitigation**: Maintain identical URL structure (`/?tab=X`, `/timeline?tab=X`) to preserve all existing links.

**[Risk] Performance impact from repeated URL reads** → **Mitigation**: Svelte's `$page` store is optimized and cached; performance impact is negligible.

**[Risk] Special character handling complexity** → **Mitigation**: Rely on SvelteKit's built-in URL encoding/decoding rather than custom logic.

**[Risk] Regression in other navigation flows** → **Mitigation**: Thorough testing of all tab switching scenarios before deployment.