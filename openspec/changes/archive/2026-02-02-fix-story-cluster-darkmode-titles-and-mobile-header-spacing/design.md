# Design: Fix story cluster dark-mode titles & mobile header spacing

Overview
- This design captures the implementation approach to fix story cluster titles appearing black in dark mode and to improve header spacing on mobile. It builds on the proposal and the `ui-styling` capability.

Dependencies
- Proposal: `proposal.md` (defines scope and capabilities).
- Existing frontend code: `assets/css/input.css`, `ui/src/Pages/Home_.elm`, `ui/src/Pages/Timeline.elm`.

Goals
- Ensure story cluster titles respect theme color variables in dark mode and meet accessibility contrast.
- Improve top header spacing on mobile for alignment and larger touch targets.
- Avoid regressions to desktop and other components that use the same variables.

Approach
- Use CSS variables and the `.dark` context to control colors. Prefer `color: var(--header-text-color)` or `color: inherit` combined with explicit variable overrides for dark mode.
- Audit selectors that currently force `color: #000` or similar and reduce specificity so theme variables can override them.
- For mobile header spacing, adjust padding and margins for the header container at mobile breakpoints (max-width / min-width rules already present). Keep desktop values unchanged.

Concrete Changes
1. CSS variable additions and fixes
   - Add `--header-text-color` and `--feed-title-color` as canonical variables (fallback to existing `--color-card-light` where appropriate).
   - Ensure dark mode overrides set these variables:
     - In dark mode block (`:where(.dark, .dark *)` or `@media (prefers-color-scheme: dark)`), set `--feed-title-color` to a light value (e.g., `#e5e7eb`) and `--header-text-color` to match computed `headerTextColor` when provided by the backend.

2. Selector fixes
   - Remove or override any rule that sets `.feed-box .feed-title { color: #000; }` or `color: inherit` that unintentionally resolves to black in dark mode.
   - Replace `.feed-box .feed-title { color: inherit; }` with `.feed-box .feed-title { color: var(--feed-title-color, inherit); }` and set the variable in dark/light contexts.

3. Mobile header spacing
   - Target the header container (class `feed-header` or the site header) and adjust padding for small screens:
     - Example: `.site-header { padding: 0.5rem 0.75rem; } @media (min-width: 640px) { .site-header { padding: 0.75rem 1rem; } }`
   - Replace icon+text layout with icon-only theme toggle where configured to save horizontal space (respect existing feature flags in codebase).

4. Elm integration
   - Use inline `style` attributes already present in `Home_.elm` and `Timeline.elm` where `headerTextColor` is applied. Ensure value falls back to CSS variables when `headerTextColor` is None.
   - Example: Element.htmlAttribute (Html.Attributes.style "color" headerTextColor) should be guarded so when headerTextColor is missing it uses `var(--header-text-color)`.

Files to modify
- assets/css/input.css
- ui/src/Pages/Home_.elm
- ui/src/Pages/Timeline.elm

Testing and Verification
- Visual checks: Light and dark mode manual verification for feed titles and header layout on mobile and desktop.
- Accessibility: Verify color contrast for feed titles in dark mode meets WCAG AA (contrast ratio >= 4.5:1 for normal text when applicable).
- Responsive: Check header spacing at common breakpoints (360px, 412px, 768px).
- Automated: Add or update snapshot tests if present for header rendering and feed header styles.

Rollout
- Implement changes behind a feature branch and run `elm-land build` and frontend snapshots.
- Deploy to staging to validate across devices. Monitor user-facing feeds for regressions.

Risks and Mitigations
- Risk: Changing variable names can break other components. Mitigation: use fallback values and keep changes minimal, scope overrides to `.feed-box` and header components.
- Risk: Backend-provided `headerTextColor` may be null — ensure sensible CSS fallbacks.

Acceptance criteria
- Feed cluster titles use a non-black color in dark mode and have acceptable contrast.
- Mobile header spacing visually improved and touch targets exceed 44x44pt (or reasonable px equivalent).
- No visual regressions on desktop.
