## Why

The frontend design system has accumulated critical correctness bugs and inconsistencies across 10 themes, 15+ components, and 3 overlapping CSS variable systems. Eight of ten themes have broken dark-mode detection (only `'dark'` string is checked, not the 8 custom dark themes), theme color definitions are triplicated across 3 files creating sync drift, `Inter` font is loaded but never applied, `sunset` is inconsistently classified as dark/light depending on which file you read, `--theme-bg-secondary` goes stale after hydration, and zero components respect `prefers-reduced-motion`. These are not cosmetic preferences — they cause invisible text, wrong colors, wasted bandwidth, and accessibility violations.

## What Changes

- **Deduplicate theme definitions** to a single source of truth, consumed by `app.html` FOUC script and `theme.svelte.ts` at runtime
- **Fix `isDark` detection** to check all 8 custom dark themes, not just the literal `'dark'` string — fixes broken theme-aware logic in `FeedBox`, `TimelineView`, and header style resolution
- **Add `sunset` to `darkThemes`** in `app.html` inline script (currently missing, causing FOUC and wrong `.dark` class toggling)
- **Fix `applyCustomThemeColors()`** to set `--theme-bg-secondary` and `--theme-text-secondary` CSS variables (currently omitted, causing stale values after hydration)
- **Wire Inter font into Tailwind config** or remove the Google Fonts `<link>` (currently loaded but never applied via `font-sans`)
- **Replace hardcoded `border-blue-500` loading spinners** with theme-aware accent color across both page routes
- **Fix `AppHeader.svelte` title text** to use `theme-text-primary` instead of hardcoded `text-slate-900 dark:text-white` (invisible on cyberpunk, matrix, etc.)
- **Add `prefers-reduced-motion` support** to cursor trail (`Effects.svelte`), border beam rotation (`BorderBeam.svelte`), mobile sheet slide (`MobileTabSheet.svelte`), and `item-appear` animation (`app.css`)
- **Create a z-index scale constant** to replace ad-hoc values (`z-[9999999]`, inline `z-index: 999999`, `z-30`, `z-40`, `z-50`, `z-[100]`)
- **Extract shared `useIsMobile()` utility** replacing 4 copy-pasted implementations (`FeedBox`, `TabSelector`, `ScrollToTop`, `LayoutPicker`)
- **Remove dead `Card.svelte` `variant` prop** (accepted but never read in `getStyle()`)
- **Remove or implement ghost `vaporwave`/`retro80s` beam theme configs** from `theme.ts` (referenced in `BEAM_THEMES` but do not exist as selectable themes)
- **Fix `spacing.default`/`spacing.spacious` token references** (referenced in 4 components but not defined in `tokens.ts`)
- **Fix hardcoded `rgba(150, 173, 141, 0.3)` touch-device glow** in `app.css` to use theme-aware shadow variable
- **Add `focus-visible` ring indicators** to all interactive header buttons, theme picker trigger, and layout picker trigger

## Capabilities

### New Capabilities
- `design-system-cleanup`: Single-source theme definitions, z-index scale, shared breakpoint utility, dead code removal, spacing token fixes
- `reduced-motion-accessibility`: `prefers-reduced-motion` support across all animated components (cursor trail, border beam, sheet transitions, item animations)

### Modified Capabilities
- `theme-tokens`: Fix `isDark` detection for all 8 custom dark themes, fix `applyCustomThemeColors()` to set `--theme-bg-secondary`/`--theme-text-secondary`, fix Inter font wiring
- `semantic-theme-tokens`: Fix hardcoded header text colors, loading spinner colors, and touch-device glow to use semantic tokens
- `theme-picker-accessibility`: Add `focus-visible` ring indicators to theme picker and all header action buttons

## Impact

**Frontend files affected:**
- `frontend/src/app.html` — FOUC script theme dedup, sunset darkThemes fix
- `frontend/src/app.css` — reduced-motion media queries, z-index cleanup, touch glow fix
- `frontend/tailwind.config.js` — Inter font family wiring
- `frontend/src/lib/stores/theme.svelte.ts` — theme dedup, isDark helper, missing CSS variables
- `frontend/src/lib/utils/themeInit.ts` — dedup or remove
- `frontend/src/lib/utils/theme.ts` — remove ghost beam themes or add as themes
- `frontend/src/lib/design/tokens.ts` — add `spacing.default`, `spacing.spacious`, z-index scale
- `frontend/src/lib/components/AppHeader.svelte` — fix title text, add focus rings
- `frontend/src/lib/components/FeedBox.svelte` — fix isDark, shared isMobile
- `frontend/src/lib/components/TimelineView.svelte` — fix isDark
- `frontend/src/lib/components/Effects.svelte` — reduced-motion support
- `frontend/src/lib/components/BorderBeam.svelte` — reduced-motion support
- `frontend/src/lib/components/MobileTabSheet.svelte` — reduced-motion support, shared isMobile
- `frontend/src/lib/components/ScrollToTop.svelte` — z-index scale, shared isMobile
- `frontend/src/lib/components/LayoutPicker.svelte` — shared isMobile, focus ring
- `frontend/src/lib/components/ThemePicker.svelte` — focus ring
- `frontend/src/lib/components/TabSelector.svelte` — shared isMobile
- `frontend/src/lib/components/ui/Card.svelte` — remove dead variant prop
- `frontend/src/routes/+page.svelte` — theme-aware loading spinner
- `frontend/src/routes/timeline/+page.svelte` — theme-aware loading spinner

**No backend changes. No API changes. No Crystal code affected.**

**Dependencies:** None — pure frontend refactoring.

**Risk:** Low-medium. Theme deduplication is the highest-risk change (must maintain FOUC prevention contract). All other changes are localized to individual components.
