## Tasks: Fix story cluster dark-mode titles & mobile header spacing

Follow these steps in order. Each task should be completed and verified before moving to the next.

- [ ] 1) Add CSS variables and dark-mode overrides
  - Update `assets/css/input.css`:
    - Add `--feed-title-color` and `--header-text-color` in `:root` with light-mode fallbacks.
    - Add dark-mode overrides under `:where(.dark, .dark *)` or `@media (prefers-color-scheme: dark)`.

- [ ] 2) Update feed title selector
  - Replace any hard-coded title colors with `color: var(--feed-title-color, inherit);` in `.feed-box .feed-title`.

- [ ] 3) Fix specificity issues
  - Audit CSS for rules that force `color: #000` on titles; remove or reduce specificity so variables can take precedence.

- [ ] 4) Mobile header spacing
  - Update header container styles to ensure minimum padding of `0.75rem` vertical and `0.75rem` horizontal on small screens (<640px).
  - Ensure header icons and toggles are at least 44x44 CSS pixels.

- [ ] 5) Elm integration
  - In `ui/src/Pages/Home_.elm` and `ui/src/Pages/Timeline.elm`, apply `headerTextColor` inline only when provided and valid; otherwise rely on CSS variables.

- [ ] 6) Accessibility checks
  - Validate contrast ratios for feed titles in dark mode. If a feed's `headerTextColor` is provided but fails contrast, fall back to `--feed-title-color`.

- [ ] 7) Tests and snapshots
  - Run `elm-land build` and update any frontend snapshots or visual tests for feed headers if applicable.

- [ ] 8) Manual QA & cross-browser testing
  - Check light/dark modes and mobile breakpoints (360px, 412px, 640px). Verify no regressions on desktop.

- [ ] 9) Finalize
  - Prepare PR with description linking to this OpenSpec change and include screenshots for before/after in dark mode and mobile.
