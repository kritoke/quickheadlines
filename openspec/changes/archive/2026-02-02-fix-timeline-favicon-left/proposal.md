## Why

The timeline page header has a favicon that is not aligned properly to the left of the page name. Currently the favicon may be offset or misaligned, making the header look inconsistent. Fixing this improves visual consistency and readability.

## What Changes

- Modify the Timeline page header layout to position the favicon to the left of the page name
- Ensure proper spacing between favicon and text
- Verify alignment works across all viewport sizes

## Capabilities

### Modified Capabilities
- `timeline-page-layout`: Update the requirement for favicon positioning in the timeline page header

## Impact

- Code: `ui/src/Pages/Timeline.elm` - header layout function
- UI: Timeline page header appearance
