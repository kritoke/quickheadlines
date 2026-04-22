## Why

The QuickHeadlines frontend has several issues that degrade user experience:
1. Scrolling fails when switching tabs/views due to competing scroll handlers and missing SvelteKit navigation lifecycle integration
2. No design token system - causing flash of wrong colors on initial render and making theme changes unreliable
3. Layout uses excessive 1800px max-width with 4-column grid that stretches content too thin
4. Too many similar themes (13 total) creating confusion

## What Changes

1. **Theme Merging**: Consolidate 13 themes into 10 by merging similar ones:
   - retro80s + vaporwave → retro
   - ocean + nord → ocean
   - forest + coffee → forest

2. **Design Token Blocking Script**: Add blocking script in `app.html` that sets CSS variables immediately before render, reading from localStorage or system preference

3. **Scrolling Fix**: Replace manual scroll handlers with SvelteKit's `onNavigate` lifecycle:
   - Remove `popstate`/`pageshow` listeners from `+layout.svelte`
   - Remove double `requestAnimationFrame` hacks from tab change handlers
   - Let SvelteKit handle scroll on navigation

4. **Layout Improvements**:
   - Change max-width from 1800px to 1400px
   - Simplify grid from 4 columns to 3 columns max

## Capabilities

### New Capabilities
- `theme-blocking-initialization`: CSS variables set before first paint to prevent flash of wrong colors
- `sveltekit-scroll-management`: Centralized scroll handling via navigation lifecycle

### Modified Capabilities
- `theme-system`: Expand to include merged themes and blocking initialization (requirements unchanged, implementation enhancement)
- `frontend-layout`: Adjust grid columns and max-width (requirements unchanged, implementation enhancement)

## Impact

- **Files Modified**:
  - `frontend/src/app.html` - Add blocking theme script
  - `frontend/src/lib/stores/theme.svelte.ts` - Merge themes
  - `frontend/src/routes/+layout.svelte` - Fix scrolling
  - `frontend/src/routes/+page.svelte` - Layout + scroll fixes
  - `frontend/src/routes/timeline/+page.svelte` - Scroll fix + max-width

- **No breaking changes** - All existing functionality preserved
- **No new dependencies** - Uses existing SvelteKit APIs
