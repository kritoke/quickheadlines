## Why

The frontend has significant code duplication and poor separation of concerns between the theme system and styling. The `app.css` file is 441 lines with hardcoded theme colors duplicated from the TypeScript theme store, and components have 10-15 inline Tailwind class bindings instead of using reusable components like the existing but unused `Card.svelte`.

## What Changes

1. **Consolidate CSS**: Remove all hardcoded theme blocks from `app.css` (lines 200-440), keeping only CSS variables, scrollbar styles, and keyframe animations (~100 lines total)
2. **Consolidate theme getters**: Replace 6 separate getter functions in `theme.svelte.ts` with single `getThemeTokens(theme)` function returning all theme data
3. **Use existing components**: Update `FeedBox.svelte` to use the `<Card>` component instead of inline Tailwind classes
4. **Hot Dog Stand preservation**: Keep theme intact (JS handles everything, CSS no longer overrides with !important)

## Capabilities

### New Capabilities
- `theme-tokens`: Centralized theme token system replacing scattered color getters

### Modified Capabilities
- None (this is purely implementation refactoring, no spec-level behavior changes)

## Impact

- `app.css`: Reduced from 441 to ~100 lines
- `theme.svelte.ts`: Consolidated 6 getters → 1 function
- `FeedBox.svelte`: Uses `<Card>` component
- All theme-aware components: Updated to use consolidated token getter
