## Why

On small viewports (mobile and narrow screens), the timeline page displays excessive spacing to the right of the content column, causing the text to appear very small and the layout to be visually unbalanced. This creates a poor user experience on mobile devices where screen real estate is limited.

## What Changes

- Adjust responsive CSS rules in the timeline page to reduce excessive horizontal spacing on small screens (< 480px width)
- Make fixed-width elements (time column, cluster padding) responsive to screen size
- Ensure single-column layout uses available space efficiently without unnecessary margins

## Capabilities

### New Capabilities
- `responsive-timeline-layout`: Implement responsive layout rules for timeline page that adapt spacing and column widths based on viewport size

### Modified Capabilities
<!-- No existing capabilities are being modified -->

## Impact

- Affected file: `ui/src/Pages/Timeline.elm` (timeline page component)
- Affected file: `views/index.html` (may need additional CSS overrides)
- No API changes
- No dependency changes
- Improves mobile user experience without affecting desktop layout