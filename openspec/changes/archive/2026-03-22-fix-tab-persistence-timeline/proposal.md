## Why

The application has critical tab persistence issues where navigation between feed view and timeline view fails to maintain the current tab selection. Additionally, timeline views for tabs with special characters (like "AI & ML") appear blank due to URL encoding/decoding problems and inconsistent state management. This creates a poor user experience where users lose their context when switching between views.

## What Changes

- **Simplify state management**: Eliminate multiple conflicting sources of truth (`feedState.activeTab`, `navigationStore.feedsTab`) and use only URL parameters as the single source of truth
- **Fix AppHeader navigation**: Replace complex props and derived state with direct reading from `$page` store for robust tab detection
- **Improve reactivity**: Replace `onMount` with proper `$effect` hooks that respond to URL parameter changes in real-time  
- **Add robust error handling**: Provide meaningful feedback when timeline items are empty or loading fails
- **Fix URL encoding issues**: Ensure proper handling of special characters in tab names throughout the navigation flow
- **Remove redundant synchronization logic**: Simplify the codebase by removing unnecessary state sync mechanisms

## Capabilities

### New Capabilities
- `tab-persistence`: Reliable tab state persistence across view navigation using URL as single source of truth
- `timeline-error-handling`: Proper display of loading states and error messages for empty or failed timeline requests

### Modified Capabilities
- `view-navigation`: Updated requirements for view switching to ensure consistent tab context preservation
- `url-parameter-handling`: Enhanced handling of special characters in URL parameters for tab names

## Impact

- **Frontend**: 
  - `frontend/src/lib/components/AppHeader.svelte` - Complete rewrite of navigation logic
  - `frontend/src/routes/+page.svelte` - Simplified state management and URL handling  
  - `frontend/src/routes/timeline/+page.svelte` - Improved reactivity and error handling
  - `frontend/src/lib/stores/navigation.svelte.ts` - Potential removal of redundant state
  - `frontend/src/lib/stores/feedStore.svelte.ts` - Reduced complexity in tab state management
- **Backend**: Minimal impact, primarily frontend fixes
- **Dependencies**: No new dependencies, uses existing Svelte 5 runes and $page store
- **User Experience**: Significantly improved tab persistence and timeline reliability