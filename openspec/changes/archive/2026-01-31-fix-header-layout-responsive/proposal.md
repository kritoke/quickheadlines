## Why

The header layout in `ui/src/Layouts/Shared.elm` has fixed horizontal padding of 16px, which causes navigation buttons to be cut off onports (<480px narrow view). This was identified after the responsive layout refactor successfully fixed Timeline and Home pages. The header needs to use the existing Responsive module for consistent padding across all pages.

## What Changes

- Update `Layouts/Shared.elm` to import the Responsive module
- Make header horizontal padding responsive using `Responsive.uniformPadding`
- Calculate breakpoint from `shared.windowWidth` using `Responsive.breakpointFromWidth`
- Keep vertical padding fixed at 16px for header height consistency

## Capabilities

### New Capabilities
- `header-responsive-padding`: Responsive header padding using centralized Responsive module

### Modified Capabilities
- No existing capabilities are being modified

## Impact

- Affected file: `ui/src/Layouts/Shared.elm` (headerView function)
- No API changes
- No backend changes
- Improves mobile navigation usability by preventing button cutoff
- Uses existing Responsive module for consistency with Timeline and Home pages