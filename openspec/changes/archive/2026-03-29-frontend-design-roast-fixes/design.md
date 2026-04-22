## Context

QuickHeadlines has a 10-theme frontend design system built on Svelte 5, Tailwind v4, and CSS custom properties. Themes are defined in three separate locations (`app.html` inline script, `theme.svelte.ts`, `themeInit.ts`) to support FOUC prevention — the inline script runs before Svelte hydrates. The system has accumulated correctness bugs where 8 of 10 themes produce incorrect rendering due to incomplete dark-mode detection, missing CSS variable propagation, hardcoded colors that bypass the theme system, and zero `prefers-reduced-motion` support.

The cursor trail and themes are non-negotiable features. The goal is to make them work correctly across all themes, not remove them.

## Goals / Non-Goals

**Goals:**
- Single source of truth for theme definitions (one file, consumed everywhere)
- Correct dark-mode behavior for all 10 themes (not just the `'dark'` literal)
- All CSS theme variables fully populated after hydration (`--theme-bg-secondary`, `--theme-text-secondary`)
- `prefers-reduced-motion` respected on all animated components
- Systematic z-index scale replacing ad-hoc values
- Shared breakpoint utility replacing 4 copy-pasted `isMobile` implementations
- Theme-aware colors everywhere (no hardcoded `blue-500`, `slate-900`, `#96ad8d`)
- Inter font either wired into Tailwind or removed from `app.html`
- Dead code removed (ghost beam themes, unused `variant` prop, broken token references)

**Non-Goals:**
- Adding new themes (vaporwave, retro80s stay as beam configs only or get removed)
- Changing the cursor trail physics or visual appearance
- Redesigning any component's layout or structure
- Backend/API changes
- Adding new components or pages
- Performance optimization of the cursor trail (beyond reduced-motion)

## Decisions

### 1. Theme Deduplication Strategy: Export constants from `theme.svelte.ts`, inline minimal subset in `app.html`

**Decision**: Keep `theme.svelte.ts` as the canonical source. In `app.html`, generate a minimal inline script that only contains the color values needed for FOUC prevention (bg, text, border, accent, shadow, bgSecondary, textSecondary) as a flat JSON-like object. Remove `themeInit.ts` entirely.

**Rationale**: The FOUC script must be self-contained (runs before modules). But we can't maintain 3 copies. By keeping the inline script as a deliberately minimal subset with a comment pointing to the canonical source, we reduce drift surface area. `themeInit.ts` provides no value beyond what `theme.svelte.ts` already handles.

**Alternative considered**: Build-time script to auto-generate the inline script from `theme.svelte.ts` — rejected because the SvelteKit static adapter + BakedFileSystem build pipeline doesn't have a natural hook point, and the inline script needs to be hand-maintained for the FOUC timing constraint.

### 2. Dark Detection: Array-based lookup

**Decision**: Create a `DARK_THEMES` constant array containing all dark-theme IDs: `['dark', 'retro', 'matrix', 'ocean', 'sunset', 'hotdog', 'dracula', 'cyberpunk', 'forest']`. Export a `isDarkTheme(theme: ThemeStyle): boolean` helper. Use it everywhere `isDark` checks are needed.

**Rationale**: Simple, explicit, easy to maintain when themes are added/removed. Replaces the broken `theme === 'dark'` pattern in `FeedBox`, `TimelineView`, and `app.html`.

### 3. Z-Index Scale: Numeric constant object in `tokens.ts`

**Decision**: Add to `tokens.ts`:
```ts
export const zIndex = {
  base: 0,
  header: 30,
  loadingBar: 20,
  dropdown: 40,
  dialog: 50,
  sheet: 100,
  toast: 100,
  scrollToTop: 200,
  effects: 300,
} as const;
```

**Rationale**: Named constants are self-documenting. The cursor trail doesn't need to be at `9999999` — it just needs to be above everything else. `300` is above `200` (scroll-to-top) which is above `100` (toasts/sheets). No more z-index arms race.

### 4. Reduced Motion: CSS-first with JS guard

**Decision**: 
- Add `@media (prefers-reduced-motion: reduce)` overrides in `app.css` for `item-appear`, `border-beam-rotate`, and `.particle-burst` animations (set `animation: none` or `animation-duration: 0.01s`)
- In `Effects.svelte`, check `window.matchMedia('(prefers-reduced-motion: reduce)').matches` before spawning cursor trail elements and click particles
- In `MobileTabSheet.svelte`, use CSS `@media` to disable slide animation

**Rationale**: CSS `@media` queries are the correct layer for motion preferences — they're always respected, don't require JS, and work before hydration. The JS guard in `Effects.svelte` is needed because the cursor trail elements are dynamically created.

### 5. Inter Font: Wire into Tailwind

**Decision**: Update `tailwind.config.js` `fontFamily.sans` to `['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif']`.

**Rationale**: Inter is a good UI font and it's already loaded. The issue is just that Tailwind doesn't know about it. One line fix. Removing the font would be wasteful of the existing preconnect setup.

### 6. Ghost Beam Themes: Remove from BEAM_THEMES array

**Decision**: Remove `'vaporwave'` and `'retro80s'` from `BEAM_THEMES` in `theme.ts`. Keep `BEAM_COLORS` entries for them (no harm, unused code). If these themes are added later, the colors are ready.

**Rationale**: Dead references in a live array is confusing. Keeping the colors as documentation is harmless.

### 7. Shared `useIsMobile`: Reactive Svelte 5 utility

**Decision**: Create `frontend/src/lib/utils/breakpoint.svelte.ts` exporting a reactive `isMobile` state:
```ts
export const breakpointState = $state({ isMobile: false });
// initialized in $effect on mount with resize listener
```

**Rationale**: Svelte 5 `$state` in a module-level object is reactive across all consumers. One resize listener instead of four. Components import and read `breakpointState.isMobile`.

## Risks / Trade-offs

**[Risk] Theme deduplication misses edge case in FOUC script** → Mitigation: The inline script in `app.html` is deliberately self-contained for timing reasons. We add a `// SYNC: keep in sync with theme.svelte.ts` comment and validate both produce identical CSS variable output in a test.

**[Risk] `isDarkTheme` check doesn't match FOUC script's dark class toggling** → Mitigation: Both use the same `DARK_THEMES` array. In `app.html` we hardcode the same list. In `theme.svelte.ts` we export the constant. We make `sunset` present in both.

**[Risk] Reduced-motion breaks cursor trail UX for users who expect it** → Mitigation: The toggle button in the header already lets users enable/disable effects. Reduced-motion users get effects disabled by default but can still toggle on. The cursor trail itself is hidden, not removed.

**[Risk] Z-index changes cause stacking context issues** → Mitigation: We're only *lowering* z-index values (from 9999999 to 300). Lower values are less likely to create unexpected stacking. The relative ordering is preserved.

**[Risk] Removing `themeInit.ts` breaks imports** → Mitigation: Grep for all imports of `themeInit` and remove/redirect them. The functionality is already in `theme.svelte.ts`.
