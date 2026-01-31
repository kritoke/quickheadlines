## Why

Story clusters in the Timeline are currently difficult to distinguish in Dark Mode ("black on dark"), and certain feeds like "CISO" and "A List Apart" have header colors that make their text unreadable in the feed box view. Improving these visual elements is critical for usability and accessibility.

## What Changes

- **Story Cluster Styling**:
  - Implement a subtle background color for expanded clusters in Dark Mode (`rgb255 31 41 55`).
  - Add a distinct bottom border to separate clusters.
  - Make the "count" button (` ↩ N`) interactive to toggle cluster expansion.
- **Feed Color Overrides**:
  - Fix "CISO" feed colors (CSO Online usually uses red/black/white).
  - Fix "A List Apart" feed colors.
  - Ensure high contrast for header text against the feed's chosen header color.

## Capabilities

### New Capabilities
- `cluster-styling`: Defines the visual requirements and interactive behavior for grouped story clusters in the timeline.
- `feed-color-overrides`: Establishes a system or specific overrides for feeds with problematic default color configurations.

### Modified Capabilities
- `timeline-layout`: Update to include cluster background and border requirements.

## Impact

- `ui/src/Pages/Timeline.elm`: Refinement of cluster view logic and styling.
- `feeds.yml`: Potential addition of `header_color` and `header_text_color` overrides for specific feeds.
- `ui/src/Theme.elm`: Potential new shared color constants.
