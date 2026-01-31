## Why

Story cluster titles are appearing as solid black in dark mode, breaking visual consistency and reducing accessibility. The top header has cramped spacing on mobile leading to poor alignment and smaller touch targets.

## What Changes

- Fix CSS/theme overrides so story cluster titles use the correct theme color in dark mode and meet contrast/accessibility requirements.
- Adjust mobile header spacing (padding/margin) to improve alignment and touch targets.

## Capabilities

### New Capabilities
- none: No new capabilities introduced; this is a UI bugfix and spacing improvement.

### Modified Capabilities
- ui-styling: Update theme overrides and component styling requirements for story clusters and header spacing.

## Impact

- Affects frontend CSS, theme variables, and header component layout across mobile breakpoints. No backend or API changes expected.
