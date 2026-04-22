## 1. Theme Foundation Fixes

- [x] 1.1 Add `DARK_THEMES` constant and `isDarkTheme()` helper to `theme.svelte.ts` — array: `['dark', 'retro', 'matrix', 'ocean', 'sunset', 'hotdog', 'dracula', 'cyberpunk', 'forest']`
- [x] 1.2 Fix `applyCustomThemeColors()` in `theme.svelte.ts` to set `--theme-bg-secondary` and `--theme-text-secondary` CSS variables
- [x] 1.3 Fix `app.html` inline script: add `sunset` to `darkThemes` array, add sync comment pointing to `theme.svelte.ts`
- [x] 1.4 Delete `frontend/src/lib/utils/themeInit.ts` and remove all imports of it
- [x] 1.5 Wire `Inter` into `tailwind.config.js` `fontFamily.sans` as first choice

## 2. Dark Detection Fixes in Components

- [x] 2.1 Fix `FeedBox.svelte` — replace `resolvedTheme === 'dark'` with `isDarkTheme(resolvedTheme)` for `getHeaderStyle()`, `getCardColors()`, `getFaviconBgStyle()`
- [x] 2.2 Fix `TimelineView.svelte` — replace `resolvedTheme === 'dark'` with `isDarkTheme(resolvedTheme)` for `getHeaderStyle()` call

## 3. Design Tokens & Shared Utilities

- [x] 3.1 Add `spacing.default` (`'16px'`) and `spacing.spacious` (`'24px'`) aliases to `tokens.ts`
- [x] 3.2 Add `zIndex` scale constant to `tokens.ts`: `{ base: 0, header: 30, loadingBar: 20, dropdown: 40, dialog: 50, sheet: 100, toast: 100, scrollToTop: 200, effects: 300 }`
- [x] 3.3 Create `frontend/src/lib/utils/breakpoint.svelte.ts` with shared reactive `breakpointState.isMobile` state

## 4. Shared Breakpoint Migration

- [x] 4.1 Migrate `FeedBox.svelte` to use `breakpointState.isMobile` — remove inline resize listener
- [x] 4.2 Migrate `TabSelector.svelte` to use `breakpointState.isMobile` — remove inline resize listener
- [x] 4.3 Migrate `ScrollToTop.svelte` to use `breakpointState.isMobile` — remove inline resize listener
- [x] 4.4 Migrate `LayoutPicker.svelte` to use `breakpointState.isMobile` — remove inline resize listener

## 5. Z-Index Migration

- [x] 5.1 Update `Effects.svelte` — replace `z-[9999999]`/`z-[9999998]` with `zIndex.effects`/`zIndex.effects - 1`
- [x] 5.2 Update `ScrollToTop.svelte` — replace inline `z-index: 999999` with `zIndex.scrollToTop`

## 6. Hardcoded Color Fixes

- [x] 6.1 Fix `AppHeader.svelte` title text — replace `text-slate-900 dark:text-white` with `theme-text-primary`
- [x] 6.2 Fix `+page.svelte` loading spinner — replace `border-blue-500` with theme-aware accent class
- [x] 6.3 Fix `timeline/+page.svelte` loading spinner — replace `border-blue-500` with theme-aware accent class
- [x] 6.4 Fix `app.css` touch device hover glow — replace hardcoded `rgba(150, 173, 141, 0.3)` with `var(--theme-shadow)` in `@media (hover: none)` block

## 7. Reduced Motion Support

- [x] 7.1 Add `@media (prefers-reduced-motion: reduce)` to `app.css` — disable `.new-item` animation and `.particle-burst`
- [x] 7.2 Update `Effects.svelte` — check `matchMedia('(prefers-reduced-motion: reduce)')` before rendering cursor trail elements and spawning particles
- [x] 7.3 Update `BorderBeam.svelte` — add `@media (prefers-reduced-motion: reduce)` to disable `border-beam-rotate` animation
- [x] 7.4 Update `MobileTabSheet.svelte` — add `@media (prefers-reduced-motion: reduce)` to disable slide-up transition

## 8. Accessibility — Focus Indicators

- [x] 8.1 Add `focus-visible:ring-2 focus-visible:ring-offset-2` ring to all `AppHeader.svelte` action buttons (search, view switch, effects toggle)
- [x] 8.2 Add `focus-visible:ring-2` to `ThemePicker.svelte` dropdown trigger
- [x] 8.3 Add `focus-visible:ring-2` to `LayoutPicker.svelte` trigger

## 9. Dead Code Cleanup

- [x] 9.1 Remove `variant` prop from `Card.svelte` Props interface and destructuring
- [x] 9.2 Remove `'vaporwave'` and `'retro80s'` from `BEAM_THEMES` array in `theme.ts`

## 10. Build Verification

- [x] 10.1 Run `just nix-build` and verify clean build
- [x] 10.2 Run `nix develop . --command crystal spec` and verify tests pass
- [x] 10.3 Run `cd frontend && npm run test` and verify frontend tests pass
