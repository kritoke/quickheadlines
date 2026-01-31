## Why

In the Timeline's story clusters, article titles are currently inheriting styles that make them difficult to see in Dark Mode (appearing as "dark text on dark background"). Additionally, missing or failed favicons can lead to unreadable feedbox headlines if the layout depends on their presence or if they fail ungracefully. Implementing a reliable favicon fallback (using Google's favicon service) and fixing link colors will improve usability.

## What Changes

- **Timeline Link Colors**:
  - Fix `clusterOtherItem` link colors to use `txtColor` (which adapts to theme) instead of inheriting potentially dark colors.
  - Update `mouseOver` colors to be consistent with the rest of the app (e.g., `lumeOrange`).
- **Favicon Fallback Strategy**:
  - Implement a fallback to Google's Favicon Service (`https://www.google.com/s2/favicons?domain=<domain>&sz=32`) when the primary favicon is missing or fails.
  - Ensure the layout remains stable and readable even if a favicon cannot be loaded.

## Capabilities

### New Capabilities
- `favicon-fallback`: Defines the strategy for resolving and displaying favicons using a secondary service when the primary fails.

### Modified Capabilities
- `timeline-layout`: Adjust link color requirements to ensure Dark Mode visibility.

## Impact

- `ui/src/Pages/Timeline.elm`: Fix `clusterOtherItem` styling and implement favicon logic.
- `ui/src/Pages/ViewIcon.elm`: Update to support fallback URLs.
- `src/parser.cr`: Potentially extract domain for Google favicon service if needed (though frontend can also do this).
