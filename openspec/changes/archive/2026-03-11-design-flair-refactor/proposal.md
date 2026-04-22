## Why

The QuickHeadlines frontend has accumulated design inconsistencies and " BorderBeam" visual effects that feel out of place in a news reader. The BorderBeam only applies to 6 of 13 themes, creating inconsistent UX. Users want a more cohesive, intentional visual flair that works across all themes.

## What Changes

- Replace BorderBeam component with theme-consistent hover glow on cards (works on all 13 themes)
- Add staggered entry animations (fly-in cascade) when feed items load
- Add particle burst effect on click (using Svelte springs for organic motion)
- Remove duplicated `customThemeIds` array by exporting from theme store
- Fix `any` type in lazy-loaded search modal
- Fix triple scroll reset to single `window.scrollTo(0, 0)`

## Capabilities

### New Capabilities
- `hover-glow`: Theme-colored shadow appears on card hover when effects enabled
- `entry-animations`: Feed items animate in with staggered fly-in effect
- `particle-burst`: Click anywhere triggers particle explosion using theme accent color

### Modified Capabilities
- `effects-toggle`: Now controls hover glow + cursor trail + particle burst (instead of just cursor trail)
- `theme-system`: All visual effects now work on all 13 themes consistently

## Impact

- **Modified files**: FeedBox.svelte, TimelineView.svelte, Effects.svelte, theme.svelte.ts, +page.svelte
- **Removed**: BorderBeam.svelte imports (file remains but unused)
- **User-facing**: More cohesive, Svelte-native animations that work across all themes
