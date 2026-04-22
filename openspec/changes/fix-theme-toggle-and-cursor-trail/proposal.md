# Proposal: Fix Theme Toggle and Cursor Trail Reactivity

## Why

The `toggleTheme()` function in `theme.svelte.ts` only toggles between `light` and `dark`, completely ignoring 8 custom themes (retro, matrix, ocean, sunset, hotdog, dracula, cyberpunk, forest). When a user with a custom theme clicks the toggle, their selected theme is silently replaced with `light` or `dark`. Additionally, the cursor trail colors may not properly react when themes change due to timing issues with the `$derived` computation.

## What Changes

1. **Fix `toggleTheme()` behavior**: Instead of blindly switching to `light`/`dark`, toggle shall cycle through user preference: if current theme is a custom theme, toggle between that custom theme's light/dark variant if variants exist, OR preserve custom theme selection while toggling an associated preference. Alternatively, if the intent is to only support light/dark toggling, the function should NOT be exposed/used when a custom theme is active.

2. **Ensure cursor trail reactivity**: Verify that `cursorColors` in `Effects.svelte` properly updates when `themeState.theme` changes by ensuring `getCursorColors()` is called with the reactive theme value.

3. **Simplify CSS variable cascade**: Remove redundant CSS variable assignments where semantic tokens already provide the correct values, reducing the fallback chain complexity.

4. **Remove unnecessary memoization**: The `themeTokenCache` in `theme.svelte.ts` caches lookups into a frozen constant object, providing no benefit.

## Capabilities

### Modified Capabilities

- `theme-tokens`: The `toggleTheme()` function's requirement to "toggle between light and dark themes" is ambiguous when custom themes exist. The spec should clarify expected behavior for custom themes during toggle.

## Impact

- **Files affected**:
  - `frontend/src/lib/stores/theme.svelte.ts` - toggleTheme(), getThemeTokens(), themeTokenCache
  - `frontend/src/lib/components/Effects.svelte` - cursorColors reactivity
  - `frontend/src/app.css` - CSS variable cascade simplification
  - `openspec/specs/theme-tokens/spec.md` - clarify toggle behavior requirements
