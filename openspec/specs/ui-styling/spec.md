# Spec: ui-styling

Capability: ui-styling

Purpose
- Define precise styling requirements and acceptance criteria for story cluster titles and the top header spacing on mobile. This spec documents the required behavior that implementation must satisfy.

Background
- Proposal: fixes for dark-mode title color and mobile header spacing. Design: outlines CSS-variable approach, selector fixes, and Elm integration fallbacks.

Requirements
1) Story cluster title color
   - Titles in feed clusters MUST use a CSS variable `--feed-title-color` for their color value.
   - In light mode the variable falls back to `#0f172a` (dark-gray). In dark mode it falls back to `#e5e7eb` (light-gray).
   - If a feed provides a `headerTextColor` from the backend, Elm must apply that inline `style="color: <value>"` on the header element. When missing, UI must rely on `--feed-title-color`.
   - No rule in the cascade should force a solid black (`#000000`) title color in dark mode.

2) Header spacing on mobile
   - The top header container (site header / feed header) must have a minimum vertical padding of 12px (0.75rem) and horizontal padding of 12px on screens narrower than 640px.
   - Touch targets (icons and toggles) within the header must be at least 44x44 CSS pixels (or closest pixel equivalent) per platform guidance.
   - At >=640px the header may use larger paddings matching existing desktop styles; changes must be constrained to mobile breakpoints only.

3) Contrast and accessibility
   - Feed title text in dark mode MUST meet WCAG AA contrast ratio of 4.5:1 against the feed box background when the font-weight is normal; for large text (>=18pt bold) the contrast requirement may be 3:1.
   - When `headerTextColor` is provided by the backend, validate contrast at render time and fall back to `--feed-title-color` if the provided color fails contrast checks or is invalid.

4) Selector and specificity rules
   - The canonical selector for the title must be `.feed-box .feed-title` and should set `color: var(--feed-title-color, inherit);` rather than a hard-coded color.
   - Avoid `!important` unless necessary; if used, document why and scope to a single component.

5) Backward compatibility
   - Existing components that depend on `color: inherit` should continue to function. Add variable fallbacks so other components are not broken.

Implementation details (guidance)
- CSS
  - Add variables to `:root` and dark-mode blocks in `assets/css/input.css`:
    - `--feed-title-color: #0f172a;`
    - `:where(.dark, .dark *) { --feed-title-color: #e5e7eb; }`
  - Update `.feed-box .feed-title`:
    ```css
    .feed-box .feed-title { color: var(--feed-title-color, inherit); }
    :where(.dark, .dark *) .feed-box .feed-title { color: var(--feed-title-color); }
    ```

- Elm
  - In `Home_.elm` and `Timeline.elm`, where `headerTextColor` is used, change rendering to:
    - If `headerTextColor` is `Just color` and the color is valid (6- or 3-digit hex), apply it inline.
    - Otherwise, do not set inline color and let CSS variables apply.

Acceptance criteria
- Visual: In dark mode, feed titles are light (not black) and have acceptable contrast; manual inspection passes for multiple feeds.
- Mobile: Header spacing increased on common device widths and touch targets are large enough.
- Regression: Desktop layout unchanged; existing snapshots updated only when intended.

Testing
- Manual QA across light/dark modes and mobile breakpoints (360px, 412px, 640px).
- Add unit tests or Elm view tests if the project has snapshot tests for feed headers.

Output path
- `openspec/changes/fix-story-cluster-darkmode-titles-and-mobile-header-spacing/specs/ui-styling/spec.md`
