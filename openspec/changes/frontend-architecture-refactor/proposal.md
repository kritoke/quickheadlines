## Why

The frontend codebase has accumulated significant technical debt that impacts maintainability, developer experience, and code quality:

1. **State Management Chaos**: Two parallel state systems exist (`feedStore.svelte.ts`, `timelineStore.svelte.ts`) but pages ignore them and re-implement state locally with `$state` variables
2. **Theme Store Duplication**: Six nearly identical color cache objects require manual editing in multiple places to add/modify themes
3. **Code Duplication**: `FeedBox.svelte` and `TimelineView.svelte` share identical helper functions (`getFaviconSrc`, beam theme logic, iOS detection)
4. **Anti-Patterns**: Custom `mounted` guards in `$effect` when Svelte 5 provides proper lifecycle tools
5. **Production Debug Logging**: ~15 console.log statements scattered throughout
6. **TypeScript Issues**: `any` types on lazy-loaded components, unused `_config` parameters
7. **Repetitive API Error Handling**: Same 6-line try/catch pattern repeated 8 times

## What Changes

- **CONSOLIDATE** state management: Pages will use stores properly, remove duplicate local state
- **UNIFY** theme configuration: Single `ThemeDefinition` object per theme, derive all color caches
- **EXTRACT** shared utilities: Create utility modules for shared feed/theme logic
- **FIX** anti-patterns: Use proper Svelte 5 patterns (`$effect` with correct dependencies, proper lifecycle)
- **REMOVE** console.log statements from production code
- **TIGHTEN** TypeScript: Proper types for lazy-loaded components, remove unused parameters
- **CREATE** API wrapper: Single `apiFetch` helper with consistent error handling

## Capabilities

### New Capabilities
- `unified-state-management`: Single source of truth for feed and timeline data via stores
- `theme-single-source`: Theme colors defined once, derived everywhere
- `shared-feed-utilities`: Common feed item rendering logic in reusable module

### Modified Capabilities
- `feed-page-state`: Now uses `feedStore` exclusively instead of local state
- `timeline-page-state`: Now uses `timelineStore` exclusively instead of local state
- `theme-switching`: Simplified with single definition per theme

## Impact

- **Files affected**: 
  - `src/lib/stores/theme.svelte.ts` (major refactor - single theme definition)
  - `src/lib/stores/feedStore.svelte.ts` (API cleanup)
  - `src/lib/stores/timelineStore.svelte.ts` (API cleanup)
  - `src/routes/+page.svelte` (remove local state, use store)
  - `src/routes/timeline/+page.svelte` (remove local state, use store)
  - `src/lib/components/FeedBox.svelte` (use shared utils)
  - `src/lib/components/TimelineView.svelte` (use shared utils)
  - `src/lib/api.ts` (add wrapper, reduce duplication)
  - NEW: `src/lib/utils/feedItem.ts` (shared feed item utilities)
  - NEW: `src/lib/utils/theme.ts` (shared theme utilities)
  - NEW: `src/lib/utils/clone.ts` (proper deep clone)
- **Breaking Changes**: Store APIs will change; pages must be updated to use new APIs
- **Dependencies**: No new dependencies
- **Testing**: Update existing tests, add tests for new utilities
