## 1. Theme System Consolidation

- [x] 1.1 Define `ThemeDefinition` interface in `src/lib/stores/theme.svelte.ts`
- [x] 1.2 Create single `themes` object with all 13 theme definitions
- [x] 1.3 Implement derived getter functions (`getCursorColors`, `getScrollButtonColors`, etc.)
- [x] 1.4 Remove all 6 cache objects (`accentColorsCache`, `cursorColorsCache`, etc.)
- [x] 1.5 Update `getThemeAccentColors()` to use new single source
- [x] 1.6 Add unit tests for theme getters
- [ ] 1.7 Verify visual regression tests pass

## 2. Shared Utilities Extraction

- [x] 2.1 Create `src/lib/utils/feedItem.ts` with `getFaviconSrc()` and `getHeaderStyle()`
- [x] 2.2 Create `src/lib/utils/theme.ts` with `getBeamColors()`, `shouldShowBorderBeam()`, `isIOS()`
- [x] 2.3 Create `src/lib/utils/clone.ts` with proper `deepClone()` implementation
- [ ] 2.4 Add unit tests for new utility modules
- [x] 2.5 Update `src/lib/utils.ts` to export new utilities

## 3. API Layer Refactor

- [x] 3.1 Create `apiFetch<T>()` wrapper function in `src/lib/api.ts`
- [x] 3.2 Refactor `fetchFeeds()` to use wrapper
- [x] 3.3 Refactor `fetchTimeline()` to use wrapper
- [x] 3.4 Refactor `fetchClusters()` to use wrapper
- [x] 3.5 Refactor `fetchClusterItems()` to use wrapper
- [x] 3.6 Refactor `fetchMoreFeedItems()` to use wrapper
- [x] 3.7 Refactor `fetchConfig()` to use wrapper
- [x] 3.8 Remove duplicate error handling code

## 4. Store API Cleanup

- [x] 4.1 Review `feedStore.svelte.ts` API - remove unused exports
- [x] 4.2 Review `timelineStore.svelte.ts` API - remove unused exports
- [x] 4.3 Replace `clone()` with proper `deepClone()` from utils
- [x] 4.4 Ensure stores export clear action functions (not just state)
- [x] 4.5 Add JSDoc comments to public store API

## 5. Feed Page Refactor

- [x] 5.1 Remove local `$state` variables that duplicate store state
- [x] 5.2 Import and use `feedStore` for all feed state
- [x] 5.3 Refactor `$effect` to follow Svelte 5 best practices
- [x] 5.4 Remove console.log statements
- [ ] 5.5 Type lazy-loaded `BitsSearchModal` properly
- [x] 5.6 Use shared utilities from `src/lib/utils/`
- [x] 5.7 Run Svelte MCP autofixer on component
- [x] 5.8 Verify functionality with manual testing

## 6. Timeline Page Refactor

- [x] 6.1 Remove local `$state` variables that duplicate store state
- [x] 6.2 Import and use `timelineStore` for all timeline state
- [x] 6.3 Refactor `$effect` to follow Svelte 5 best practices
- [x] 6.4 Remove console.log statements
- [ ] 6.5 Type lazy-loaded components properly
- [x] 6.6 Use shared utilities from `src/lib/utils/`
- [ ] 6.7 Run Svelte MCP autofixer on component
- [x] 6.8 Verify functionality with manual testing

## 7. Component Updates

- [x] 7.1 Update `FeedBox.svelte` to use `getFaviconSrc` from utils
- [x] 7.2 Update `FeedBox.svelte` to use beam utilities from utils
- [x] 7.3 Run Svelte MCP autofixer on FeedBox
- [x] 7.4 Update `TimelineView.svelte` to use `getFaviconSrc` from utils
- [x] 7.5 Update `TimelineView.svelte` to use beam utilities from utils
- [ ] 7.6 Run Svelte MCP autofixer on TimelineView
- [x] 7.7 Remove duplicate helper functions from both components

## 8. Effects System Cleanup

- [x] 8.1 Remove unused `_config` parameter from `createFeedEffects()`
- [x] 8.2 Remove unused `_config` parameter from `createTimelineEffects()`
- [x] 8.3 Remove console.log statements from effects
- [x] 8.4 Review and simplify effect lifecycle management

## 9. WebSocket Connection Cleanup

- [x] 9.1 Remove console.log statements from `connection.ts`
- [x] 9.2 Review and document the singleton pattern
- [x] 9.3 Ensure proper TypeScript types (no `any`)

## 10. Final Verification

- [x] 10.1 Run `just nix-build` - must succeed
- [ ] 10.2 Run `nix develop . --command crystal spec` - must pass
- [x] 10.3 Run `cd frontend && npm run test` - must pass
- [ ] 10.4 Run visual regression tests
- [ ] 10.5 Manual testing of all 13 themes
- [ ] 10.6 Manual testing of feed page functionality
- [ ] 10.7 Manual testing of timeline page functionality
- [ ] 10.8 Verify no console.log in browser console during normal operation
- [ ] 10.9 Code review for any remaining `any` types
