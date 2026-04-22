## Why

The FeedBox component has 12+ inline Tailwind class bindings that duplicate the styling already defined in the reusable `<Card>` UI component. Refactoring FeedBox to use Card will reduce code duplication, improve maintainability, and ensure consistent styling across the application.

## What Changes

1. Add theme-aware variant support to `Card.svelte` component
2. Refactor `FeedBox.svelte` to use `<Card>` component instead of inline Tailwind classes
3. Remove duplicate CSS classes from FeedBox that Card already provides
4. Apply theme-aware styling via CSS variables through Card props

## Capabilities

### New Capabilities
- `feed-card`: Reusable feed card component using the Card UI primitive with theme support

### Modified Capabilities
- `theme-tokens`: Updated to include Card component requirements (already exists from previous change)

## Impact

- `Card.svelte`: Add `themeVariant` prop for theme-aware styling
- `FeedBox.svelte`: Replace ~12 class bindings with Card component usage
- `app.css`: No changes needed (Card uses CSS variables)
