## Why

The current TabBar.svelte uses a manual implementation with basic styling that lacks the "Luxe" aesthetic, smooth animations, and proper ARIA accessibility. Additionally, the existing CoolMode (polka dot particles) should be replaced with a more refined cursor trail effect using Svelte 5 spring physics.

This refactor will:

1. Replace TabBar with Bits UI-powered FeedTabs for full keyboard navigation and ARIA compliance
2. Add a sliding pill background animation for the active tab
3. Implement a spring-based cursor trail with primary dot and blurred aura
4. Preserve existing functionality: URL query param sync, scroll-to-active, tab caching

## What Changes

- Create new `FeedTabs.svelte` component using Bits UI Tabs primitives
- Create new `CursorTrail.svelte` component using Svelte 5 spring runes
- Replace TabBar.svelte and CoolMode.svelte usage in `+page.svelte`
- Add luxe color palette and inner-shadow utilities to Tailwind config
- Add CSS for View Transitions and luxe glass effects to app.css
- Update theme state: rename `coolMode` to `cursorTrail`

## Capabilities

### New Capabilities
- `luxe-tab-navigation`: Keyboard-navigable tabs with ARIA compliance via Bits UI
- `sliding-pill-animation`: Animated active tab indicator with physics-based easing
- `cool-mode-tab-glow`: Optional glow effect on active tab when cursorTrail is enabled
- `cursor-trail-effect`: Spring-based cursor follower with primary dot and blurred aura

### Modified Capabilities
- `ui-theming`: Add luxe color palette, inner shadows, and glass effects

## Impact

- Files modified:
  - `frontend/src/lib/components/FeedTabs.svelte` (new)
  - `frontend/src/lib/components/CursorTrail.svelte` (new)
  - `frontend/src/routes/+page.svelte` (update to use FeedTabs and CursorTrail)
  - `frontend/src/lib/stores/theme.svelte.ts` (rename coolMode to cursorTrail)
  - `frontend/tailwind.config.js` (add luxe colors/shadows)
  - `frontend/src/app.css` (add view transition CSS, glass utilities)
- Files deprecated:
  - `frontend/src/lib/components/TabBar.svelte` (replaced by FeedTabs)
  - `frontend/src/lib/components/CoolMode.svelte` (replaced by CursorTrail)
- No backend or API changes
