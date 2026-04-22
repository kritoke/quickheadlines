## Why

The frontend suffers from fragile navigation and scroll behavior due to mixed navigation patterns (full page reloads vs client-side routing), inconsistent scroll management, and ad-hoc state initialization. This causes UI issues when switching views, scrolling breaks frequently, and changes to one area cascade into unexpected behavior elsewhere. A unified navigation architecture will fix these issues.

## What Changes

- Replace `window.location.href` navigation in AppHeader with SvelteKit's `goto()` for proper SPA navigation
- Create a `navigationStore` to track and restore scroll position per route
- Add layout-level navigation lifecycle hooks using SvelteKit's `onNavigate` 
- Fix feed page aggressive scroll reset (remove manual scroll manipulation)
- Add proper scroll restoration on route transitions
- Simplify page initialization by using proper lifecycle hooks instead of complex `$effect` guards

## Capabilities

### New Capabilities

- `unified-navigation`: Centralized navigation and scroll management across all routes
  - Scroll position saving/restoring per route path
  - Consistent SPA navigation without full page reloads
  - Lifecycle hooks for before/after navigation

### Modified Capabilities

- None (this is a refactoring with no requirement changes to existing specs)

## Impact

- **Files Modified**: 
  - `src/lib/components/AppHeader.svelte` - Fix navigation to use `goto()`
  - `src/lib/utils/scroll.ts` - Replace with navigationStore
  - `src/routes/+layout.svelte` - Add navigation lifecycle handling
  - `src/routes/+page.svelte` - Simplify initialization
  - `src/routes/timeline/+page.svelte` - Add scroll management
