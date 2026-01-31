## Context

Story clusters in the Timeline are visually indistinguishable from standalone items in Dark Mode when expanded. Additionally, certain feeds have default color schemes (or lack thereof) that result in unreadable text in the dashboard view.

## Goals / Non-Goals

**Goals:**
- Improve visual contrast for expanded story clusters in the Timeline.
- Fix color contrast issues for "CISO" and "A List Apart" feeds.
- Ensure all feeds remain legible in both Light and Dark modes.

**Non-Goals:**
- Redesigning the entire dashboard or timeline layout.
- Implementing automatic color contrast detection/adjustment logic in the frontend.

## Decisions

- **Cluster Styling**: 
  - Use `rgb255 31 41 55` (Slate 800) as the background for expanded clusters in Dark Mode. 
  - Use `rgb255 248 250 252` (Slate 50) for Light Mode.
  - Implement a `Border.widthEach { bottom = 1, ... }` with `Theme.borderColor` for consistent separation.
- **Feed Configuration**: 
  - Directly override colors in `feeds.yml` for problematic feeds.
  - **CISO**: Header Color `#c41230` (CSO Red), Header Text `#ffffff`.
  - **A List Apart**: Header Color `#222222` (Dark Grey), Header Text `#ffffff`.
- **Interactivity**: 
  - The ` ↩ N` count button will trigger `ToggleCluster <id>`, which updates the `expandedClusters` Set in the model.

## Risks / Trade-offs

- **Risk**: Hardcoded overrides in `feeds.yml` might become stale if the site changes branding.
- **Mitigation**: These are easily updated in the YAML file.
- **Risk**: Too much background color in the Timeline might look cluttered.
- **Mitigation**: Using very subtle slate tones (800 for dark, 50 for light) to provide just enough distinction.
