## Why

Server-provided feed header colors are the source of truth for feed branding, but timing and re-render races in the client cause those colors to be lost or rendered with poor contrast (white on white or black on black) after tab switches or timeline re-renders. Making the Elm UI deterministically render server header colors (title pill + readable text color) removes racey JS fixes and ensures consistent, accessible visuals across themes.

## What Changes

- Elm: Update `ui/src/Pages/Timeline.elm` to always render a small background "title pill" and an explicit inline text color for any timeline item that includes `headerColor` or `headerTextColor` from the server. This will be applied for representative items and cluster "other" items.
- JS: Keep defensive extraction in `views/index.html` but no longer rely on it for feeds that include server colors. JS will only patch items that lack server metadata.
- Tests: Add/update Playwright tests to verify colors persist across tab switches, theme toggles, and re-renders in both light and dark themes.

## Capabilities

### New Capabilities
- `elm-deterministic-header-colors`: Elm will deterministically render server-supplied header colors as a background pill and readable inline text color for timeline items.

### Modified Capabilities
- `ui-timeline-contrast`: Update the timeline UI's expectations so server-supplied header colors are authoritative and always rendered by Elm when present. (This is a UI-level requirement change.)

## Impact

- Files changed: `ui/src/Pages/Timeline.elm`, `ui/src/Pages/Home_.elm` (if necessary), `views/index.html` (minor), and `ui/tests/*` (Playwright tests).
- No API changes; the server still sends `headerColor`/`headerTextColor` in timeline item payloads.
- Risk: Visual diffs in Playwright snapshots may require updating expectations. Ensure tests are updated accordingly.
