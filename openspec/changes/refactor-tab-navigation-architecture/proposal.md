## Why

The current tab navigation and state management system suffers from multiple conflicting sources of truth, bidirectional data flow, and inconsistent component responsibilities. This creates race conditions, infinite loops, broken tab persistence, excessive API calls, and makes the codebase fragile and difficult to maintain. Every attempt to fix one issue breaks another because the underlying architecture is fundamentally flawed.

## What Changes

- **Eliminate intermediate tab state**: Remove `feedState.activeTab` and `navigationStore.feedsTab` entirely - URL parameters become the single source of truth
- **Centralize navigation logic**: Create dedicated navigation service to handle all view switching consistently  
- **Simplify AppHeader**: Make it purely presentational with no navigation or state logic
- **Standardize page patterns**: Both feed and timeline pages follow identical initialization and URL handling patterns
- **Fix reactivity patterns**: Replace problematic `$effect` usage with proper `onMount` + guarded `$effect` patterns
- **Remove redundant synchronization**: Eliminate all cross-component state sync code that causes race conditions

## Capabilities

### New Capabilities
- `url-based-navigation`: Robust navigation system using URL parameters as single source of truth
- `navigation-service`: Centralized service for consistent view switching and URL management
- `simplified-appheader`: Pure presentational header component with no state or navigation logic

### Modified Capabilities
- `view-navigation`: Updated to use centralized navigation service instead of scattered logic
- `tab-persistence`: Modified to rely solely on URL parameters rather than multiple state sources
- `timeline-page-layout`: Updated to use standardized page pattern with proper effect guards

## Impact

- **Frontend**: 
  - `frontend/src/lib/stores/feedStore.svelte.ts` - Remove activeTab state
  - `frontend/src/lib/stores/navigation.svelte.ts` - Remove feedsTab state  
  - `frontend/src/lib/components/AppHeader.svelte` - Simplify to presentational only
  - `frontend/src/routes/+page.svelte` - Standardize initialization pattern
  - `frontend/src/routes/timeline/+page.svelte` - Standardize initialization pattern
  - `frontend/src/lib/services/navigationService.ts` - NEW: Centralized navigation service
- **Performance**: Eliminates redundant API calls, state updates, and re-renders
- **Maintainability**: Reduces code complexity by ~50%, clear separation of concerns
- **Reliability**: Eliminates race conditions and infinite loops permanently