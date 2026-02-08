## Why

The timeline title pills render with excess vertical space on mobile due to the default line-height and padding. A small, theme-aware tightening of line-height on mobile reduces clipping and visual jitter during hydration. This change fixes the source Elm code (not the compiled bundle), ensures the bundle is rebuilt in optimized mode for release, and documents the process.

## What Changes

- Update source Elm: `ui/src/Pages/Timeline.elm` — replace the inline `Html.Attributes.style "line-height"` usage with a theming/typography-driven attribute so mobile line-height tightening uses a centralized helper.
- Rebuild Elm bundle in optimized mode and minify output (`public/elm.js`) — do not hand-edit compiled artifacts.
- Add an OpenSpec change documenting the fix and verification steps.
- Verify visual regressions with Playwright; update snapshots if the change is intentional.

## Capabilities

### New Capabilities
- `timeline-mobile-typography`: Centralize mobile-specific typography adjustments for timeline title pills so they are theme-aware and testable.

### Modified Capabilities
- None

## Impact

- Files changed: `ui/src/Pages/Timeline.elm`, `public/elm.js` (rebuilt), OpenSpec artifacts under `openspec/changes/timeline-mobile-lineheight-fix/`.
- Tests: Playwright visual snapshots may need updating. Backend unaffected.
- Build: Requires running Elm build with `--optimize` and a JS minifier in the release pipeline.
