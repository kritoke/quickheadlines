## Why

The timeline view currently shows favicons positioned above site names, which breaks visual alignment and reduces scanability for readers. Fixing the favicon position improves visual hierarchy and makes the timeline easier to scan.

## What Changes

- Adjust the timeline item layout so the favicon appears inline with the site name, vertically centered with the headline text.
- Update CSS/Elm Land layout primitives to prevent favicons from floating above text when items wrap.
- Add a visual regression test for timeline rendering across narrow and wide viewports.

## Capabilities

### New Capabilities
- `timeline-favicon-alignment`: Ensure favicons are positioned inline with site names in the timeline view and remain aligned across responsive breakpoints.

### Modified Capabilities
- `timeline-layout`: Adjust minor layout requirements to require consistent inline alignment of site icons with text (no semantic behavior changes).

## Impact

- Frontend: `src/frontend` Elm Land views for the timeline; CSS/Element layout primitives.
- Tests: visual snapshot/regression tests for the timeline component.
- No backend API changes expected.
