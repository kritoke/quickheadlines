# Tasks: Fix Theme Toggle and Cursor Trail Reactivity

## 1. Fix toggleTheme() Function

- [x] 1.1 Update `toggleTheme()` in `theme.svelte.ts` to handle custom themes by toggling to `light` or `dark` based on whether custom theme is light-like or dark-like

## 2. Remove Unnecessary Code

- [x] 2.1 Remove `themeTokenCache` from `theme.svelte.ts`
- [x] 2.2 Remove `getThemeTokens()` function from `theme.svelte.ts`
- [x] 2.3 Remove `clearThemeTokenCache()` function from `theme.svelte.ts`

## 3. Verify Cursor Trail Reactivity

- [x] 3.1 Review `cursorColors` derivation in `Effects.svelte` to ensure it reads from reactive `themeState.theme`
- [x] 3.2 Add inline comment clarifying the reactive dependency

## 4. Build and Test

- [x] 4.1 Run `just nix-build` to verify compilation
- [x] 4.2 Test theme toggle from light → dark → light (via tests)
- [x] 4.3 Test theme toggle from custom theme (e.g., matrix) → should go to light (via tests)
- [x] 4.4 Test cursor trail color changes with theme switch (via tests)
- [x] 4.5 Run frontend tests: `cd frontend && npm run test`
