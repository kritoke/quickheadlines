## Why

The site titles in the timeline view appear visually too tall on mobile: there is too much vertical space around the feed title pill and it looks cramped against the separator lines above and below. This reduces visual clarity on narrow viewports and makes scanning the timeline harder.

## What Changes

- Adjust timeline title vertical spacing and line-height to improve visual density on small viewports.
- Modify Elm view for timeline items (`ui/src/Pages/Timeline.elm`) to apply smaller vertical padding and a tighter line-height for the title pill when the breakpoint is mobile/very-narrow.
- Add fallback CSS rules in `views/index.html` (mobile media query) to enforce tighter line-height/padding for timeline title elements if needed.

## Capabilities

### New Capabilities
- `timeline-compact-titles`: Reduce vertical padding and set mobile-specific line-height for timeline site title elements so titles fit comfortably between separators on mobile devices.

### Modified Capabilities
- None

## Impact

- Files to change: `ui/src/Pages/Timeline.elm`, `views/index.html`.
- No API or backend changes.
- Visual/UX change only; may require updating Playwright visual snapshots.
- Risks: small CSS/Elm changes may cause minor pixel diffs in visual tests. Plan to update snapshots if diffs are intentional.
