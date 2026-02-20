## Why

The current TabBar.svelte uses a manual implementation with basic styling. The refactor replaces it with Bits UI-powered FeedTabs component that provides:

1. Full keyboard navigation and ARIA compliance via Bits UI Tabs
2. A sliding pill background animation for the active tab
3. Luxe styling with accent color glow (Wasabi Green)
4. View Transitions API support for smooth animations
5. Preserves existing functionality: URL query param sync, tab caching

## What Changes

- Create new `FeedTabs.svelte` component using Bits UI Tabs primitives
- Replace TabBar.svelte usage in `+page.svelte` with FeedTabs
- Add accent color (Wasabi Green #96ad8d) and shadow to Tailwind config
- Add View Transition CSS to app.css
- Update header toggle icon to cursor icon

## Capabilities

### New Capabilities
- `luxe-tab-navigation`: Keyboard-navigable tabs with ARIA compliance via Bits UI
- `sliding-pill-animation`: Animated active tab indicator with fly transition
- `cool-mode-tab-glow`: Glow effect on active tab when coolMode enabled

### Modified Capabilities
- `ui-theming`: Add accent color and luxe-glow shadow

## Impact

- Files modified:
  - `frontend/src/lib/components/FeedTabs.svelte` (new)
  - `frontend/src/routes/+page.svelte` (update imports)
  - `frontend/src/lib/components/Header.svelte` (update icon)
  - `frontend/src/routes/timeline/+page.svelte` (update icon)
  - `frontend/tailwind.config.js` (add accent colors)
  - `frontend/src/app.css` (add view transition CSS)
- No backend changes
