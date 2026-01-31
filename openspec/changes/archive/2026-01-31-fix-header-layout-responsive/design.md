## Context

The shared layout header in `Layouts/Shared.elm` uses fixed horizontal padding of 16px on all viewport sizes:

```elm
row
    [ width fill
    , padding 16
    ]
```

On narrow screens (<480px), this padding consumes significant screen real estate, causing navigation buttons to be cut off. The Responsive module already provides `uniformPadding` function with appropriate values for each breakpoint.

## Goals / Non-Goals

**Goals:**
- Make header padding responsive using centralized Responsive module
- Maintain consistent vertical padding (16px) for header height
- Improve mobile navigation experience
- Reuse existing Responsive helpers

**Non-Goals:**
- Change header layout structure or information architecture
- Modify footer implementation
- Add new dependencies beyond Responsive module

## Decisions

**Use Responsive.uniformPadding for horizontal padding**
- Rationale: Consistent padding strategy across all pages
- Alternative: Keep fixed 16px - rejected due to button cutoff

**Calculate breakpoint from shared.windowWidth**
- Rationale: Consistent with Timeline and Home pages
- Alternative: Inline calculations - rejected for maintainability

## Migration Plan

1. Import Responsive module in Layouts/Shared.elm
2. Update headerView function to accept Shared.Model
3. Add breakpoint calculation and uniformPadding usage
4. Update layout function to pass model to headerView
5. Build verification and testing

## Open Questions

1. Should vertical padding also be made responsive? (Currently keeping fixed at 16px)