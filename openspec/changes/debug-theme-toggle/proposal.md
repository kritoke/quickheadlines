## Why

The timeline's header and link colors are inconsistent when the user toggles the site theme. Elm should be the single source of truth for runtime color decisions, but some server-provided colors and legacy JS/CSS can override or conflict with Elm's rendering. This change creates a short, focused debugging and fix effort to ensure theme toggles update timeline text color reliably.

## What Changes

- Add instrumentation and a small debug UI to surface computed colors in the timeline to make reproducing the issue easier.
- Audit and remove any remaining JS that writes inline styles to timeline header/link elements or that races Elm rendering.
- Ensure Shared.ToggleTheme updates flow and that Timeline.view uses Shared.theme for computed Font.color values in all relevant locations.
- Add an OpenSpec task package documenting tests to run (Elm build + Playwright timeline-contrast) and steps to verify.

## Capabilities

### New Capabilities
- `debug-theme-toggle`: Debug visibility and verification for theme toggle color application in the Elm timeline view.

### Modified Capabilities
- `ui-theming`: (delta) Clarify that Elm is the authoritative runtime source for theme colors and that JS must not set inline styles that override Elm. This updates expectations but not external APIs.

## Impact

- Files to change: `ui/src/Pages/Timeline.elm`, `ui/src/Application.elm`, `views/index.html` (remove JS overrides), `public/elm.js` (rebuilt), and Playwright tests under `ui/tests/`.
- Requires rebuilding Elm (`cd ui && elm make`) and running Playwright tests.
- Low risk: UI-only changes. No backend or API modifications required.
