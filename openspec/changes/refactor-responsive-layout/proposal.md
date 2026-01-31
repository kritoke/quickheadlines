## Why

The codebase has scattered responsive layout logic with inconsistent breakpoint definitions, leading to layout issues including header cutoff, content squeezing, and text becoming unreadable on mobile devices. Different pages use different padding strategies (Timeline: separate horizontal/vertical, Home: uniform), and breakpoint values are hardcoded throughout, making maintenance difficult and risking inconsistent behavior.

## What Changes

- Create new `ui/src/Responsive.elm` module to centralize breakpoint definitions and responsive value calculations
- Define standardized 4-tier breakpoint system: VeryNarrow (<480px), Mobile (480-767px), Tablet (768-1023px), Desktop (≥1024px)
- Refactor `ui/src/Pages/Timeline.elm` to use Responsive module helpers instead of local calculations
- Refactor `ui/src/Pages/Home_.elm` to use Responsive module helpers and add missing max-width constraints
- Standardize padding and layout behavior across both pages
- **BREAKING**: Update function signatures to accept `Breakpoint` type instead of `Bool` flags or `Int` windowWidth

## Capabilities

### New Capabilities
- `responsive-breakpoint-system`: Centralized breakpoint definitions and responsive helper functions for consistent layout behavior across all pages

### Modified Capabilities
<!-- No existing capabilities are being modified -->

## Impact

- Affected files: `ui/src/Responsive.elm` (new), `ui/src/Pages/Timeline.elm`, `ui/src/Pages/Home_.elm`
- No API changes
- No backend changes
- Improves mobile user experience by fixing layout cutoff and content squeezing issues
- Establishes maintainable pattern for future responsive development