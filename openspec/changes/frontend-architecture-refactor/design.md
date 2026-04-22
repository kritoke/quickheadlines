## Context

The frontend has evolved organically, resulting in:

- **State schizophrenia**: Stores exist but pages duplicate their functionality with local `$state` variables
- **Theme definition sprawl**: Adding a theme requires editing 6 separate cache objects with ~40 hex codes total
- **Copy-paste architecture**: `getFaviconSrc()` exists in multiple files, beam theme colors duplicated
- **Reinvented lifecycle**: `$effect(() => { if (!mounted) { mounted = true; ... }})` is an anti-pattern in Svelte 5
- **Fragile cloning**: `JSON.parse(JSON.stringify(obj))` silently drops Sets, Dates, undefined, functions

### Current Pain Points

```
theme.svelte.ts:
- accentColorsCache: 13 themes × 6 properties = 78 entries
- cursorColorsCache: 13 themes × 2 properties = 26 entries  
- scrollButtonColorsCache: 13 themes × 3 properties = 39 entries
- dotIndicatorColorsCache: 13 themes × 1 property = 13 entries
- customThemeColorsCache: 13 themes × 5 properties = 65 entries
- themePreviewCache: 13 themes × 1 property = 13 entries
Total: 234 manual hex code entries to maintain
```

## Goals / Non-Goals

**Goals:**
- Single source of truth for application state via stores
- Theme colors defined exactly once per theme
- Shared utilities for common feed/timeline operations
- Proper TypeScript types throughout
- Zero console.log in production code
- Reduce total frontend code by ~15%
- Follow Svelte 5 best practices

**Non-Goals:**
- UI/UX changes (this is purely architectural)
- Backend changes
- Adding new features
- Changing component structure or file organization radically

## Decisions

### 1. Store-First Architecture
**Decision**: Pages must use stores as single source of truth; remove local state duplication.

**Rationale**: Having both stores and local state creates synchronization bugs, makes debugging harder, and doubles the code. Stores exist - use them.

**Implementation**: 
- `feedStore` provides reactive state and actions
- `timelineStore` provides reactive state and actions
- Pages dispatch actions to stores, reactively render from store state using `$derived`

### 2. Single Theme Definition
**Decision**: Each theme defined as single `ThemeDefinition` object; all caches derived via getters.

**Rationale**: DRY principle. Adding/editing a theme should require changing exactly one object.

**Implementation**:
```typescript
interface ThemeDefinition {
  id: ThemeStyle;
  name: string;
  description: string;
  colors: {
    bg: string;
    bgSecondary: string;
    text: string;
    border: string;
    accent: string;
    shadow: string;
  };
  cursor: { primary: string; trail: string };
  scrollButton: { bg: string; text: string; hover: string };
  dotIndicator: string;
  preview: string;
}

const themes: Record<ThemeStyle, ThemeDefinition> = {
  light: { id: 'light', name: 'Light', ... },
  // ...
};
```

### 3. Shared Utility Modules
**Decision**: Extract common logic to `src/lib/utils/` modules.

**Rationale**: `getFaviconSrc()` is duplicated. Beam theme logic is duplicated. Centralize these.

**Implementation**:
- `src/lib/utils/feedItem.ts`: `getFaviconSrc()`, `getHeaderStyle()`
- `src/lib/utils/theme.ts`: `getBeamColors()`, `shouldShowBorderBeam()`, `isIOS()`
- `src/lib/utils/clone.ts`: Proper `deepClone()` using structuredClone

### 4. API Wrapper
**Decision**: Create `apiFetch<T>()` wrapper that handles errors consistently.

**Rationale**: Same 6-line try/catch with toastStore.error() repeated 8 times.

**Implementation**:
```typescript
async function apiFetch<T>(url: string, errorMessage: string, toastTitle: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) {
    const msg = `${errorMessage}: ${response.statusText}`;
    toastStore.error(msg, toastTitle);
    throw new Error(msg);
  }
  return response.json();
}
```

### 5. Svelte 5 Effect Patterns
**Decision**: Use `$effect` correctly with proper dependency tracking, not mount guards.

**Rationale**: In Svelte 5, `$effect` tracks dependencies automatically. The `if (!mounted)` pattern is unnecessary and error-prone.

**Correct patterns**:
```svelte
// For initialization that should run once
$effect(() => {
  loadFeeds();
  loadConfig();
  
  // Cleanup function
  return () => {
    websocketConnection.removeEventListener(handler);
  };
});

// For reactive side effects
$effect(() => {
  if (sentinelElement && hasMore) {
    const observer = new IntersectionObserver(...);
    return () => observer.disconnect();
  }
});
```

### 6. Proper TypeScript for Lazy Components
**Decision**: Type lazy-loaded components properly using `ComponentType`.

```typescript
import type { ComponentType } from 'svelte';

let LazySearchModal: ComponentType | null = $state(null);
```

## Risks / Trade-offs

**[Risk] Breaking existing functionality during refactor** → **Mitigation**: Comprehensive test coverage before changes; incremental migration with tests passing at each step.

**[Risk] Store API changes break pages** → **Mitigation**: Update all page components in same PR; full E2E testing.

**[Risk] Theme definition changes cause visual regressions** → **Mitigation**: Visual regression tests (Playwright snapshots); manual theme review.

**[Trade-off] Larger PR size vs incremental fixes** → **Acceptance**: These issues are interconnected; fixing them together is more efficient than partial fixes that require rework.

**[Risk] Svelte 5 reactivity edge cases** → **Mitigation**: Use Svelte MCP autofixer to validate components; test thoroughly.
