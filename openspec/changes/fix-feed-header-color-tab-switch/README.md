Change: fix-feed-header-color-tab-switch

This change fixes a UI regression where feed header link text becomes unreadable (black) after switching tabs or when the Timeline view re-renders. It makes these adjustments:

- Remove usage of `!important` in stylesheet rules that force link colors so inline styles and Elm-provided server colors stay authoritative.
- Replace remaining `style.setProperty(..., 'important')` calls with plain inline `style.color = ...` assignments.
- Ensure client JS skips applying or overriding colors for headers with `data-use-server-colors="true"`.

Files modified:
- `views/index.html` — CSS and JS fixes

Next steps:
1. Rebuild Elm (`cd ui && elm make src/Main.elm --output=../public/elm.js`) so Elm changes that add `data-use-server-colors` and inline header text colors take effect.
2. Run Playwright tests: `nix develop . --command npx playwright test ui/tests/tab-switch-colors.spec.ts`
3. Iterate if tests show residual issues (add small debounces or defensive checks during mutation observer runs).
