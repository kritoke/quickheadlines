## Why

The header layout in `Layouts/Shared.elm` has fixed horizontal padding of 16px (8px on each side), which causes navigation buttons to be cut off on narrow and small viewports. On screens under 480px wide, this consumes significant screen real estate, making it difficult or impossible to see or interact with navigation elements.

## What Changes

- Make header padding responsive based on viewport width
- Import Responsive module in `Layouts/Shared.elm`
- Calculate breakpoint from `shared.windowWidth` using `Responsive.breakpointFromWidth`
- Use `Responsive.uniformPadding` for horizontal padding (8px on very narrow, 16px on mobile, 32px on tablet, 96px on desktop)
- Keep vertical padding fixed at 16px to maintain header height consistency

## Capabilities

### New Capabilities
- `responsive-header-padding`: Responsive header padding that adapts to viewport size for better mobile navigation experience

### Modified Capabilities
- No existing capabilities are being modified

## Impact

- Affected file: `ui/src/Layouts/Shared.elm` (headerView function)
- No API changes
- No backend changes
- Improves mobile navigation usability by preventing buttons from being cut off
- Uses existing Responsive module for consistency with Timeline and Home pages