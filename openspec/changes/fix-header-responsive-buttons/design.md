## Context

Current header implementation in `Layouts/Shared.elm` uses fixed horizontal padding of 16px on all viewport sizes. The headerView function has:

```elm
row
    [ width fill
    , padding 16
    ]
```

On narrow screens (<480px), 16px of horizontal padding consumes approximately 3.3% of screen width, causing navigation buttons (tabs) to be cut off or truncated. This is especially problematic after the responsive layout refactor which successfully fixed Timeline and Home pages to use the new Responsive module.

The Responsive module already provides a `uniformPadding` function that returns appropriate padding based on breakpoint:
- VeryNarrow (<480px): 8px
- Mobile (480-767px): 16px
- Tablet (768-1023px): 32px
- Desktop (≥1024px): 96px

## Goals / Non-Goals

**Goals:**
- Make header padding responsive using the centralized Responsive module
- Maintain consistent vertical padding (16px) to preserve header height
- Improve mobile navigation experience by preventing button cutoff
- Reuse existing Responsive helpers for maintainability

**Non-Goals:**
- Change header layout structure or information architecture
- Modify footer implementation (separate component)
- Add new dependencies beyond Responsive module (already imported by pages)

## Decisions

**Use Responsive.uniformPadding for horizontal padding**
- Decision rationale: Provides consistent padding strategy across all pages (Timeline, Home, now Header)
- Alternative considered: Keep fixed 16px - rejected due to button cutoff on narrow screens

**Import Responsive module in Layouts/Shared.elm**
- Decision rationale: Required to access breakpoint and uniformPadding functions
- Alternative considered: Implement inline width calculations - rejected for maintainability

**Calculate breakpoint from shared.windowWidth**
- Decision rationale: Consistent approach used by Timeline and Home pages
- Alternative considered: Use viewport width directly - rejected for consistency

**Keep vertical padding fixed at 16px**
- Decision rationale: Header height should remain consistent across all viewports
- Alternative considered: Make vertical padding responsive - rejected to avoid header height changes

## Risks / Trade-offs

**Header Height Change**
- Risk: Changing vertical padding might break visual balance with content
- Mitigation: Keep vertical padding fixed at 16px, only make horizontal padding responsive

**Padding Consistency**
- Risk: Different padding values might feel inconsistent if not tested thoroughly
- Mitigation: Test on actual devices and browser dev tools across all breakpoints

**Migration Plan**

**Step 1: Import Responsive module**
- Add `import Responsive exposing (Breakpoint(..), breakpointFromWidth, uniformPadding)` to `Layouts/Shared.elm`

**Step 2: Update headerView function**
- Add breakpoint calculation: `breakpoint = Responsive.breakpointFromWidth shared.windowWidth`
- Update padding to use Responsive.uniformPadding

**Step 3: Update function signature**
- Add `Shared.Model` parameter to headerView for access to windowWidth
- Update calls to headerView in layout function to pass shared model

**Step 4: Build verification**
- Compile Elm application
- Test on different viewport sizes (<480, 480-767, 768-1023, ≥1024)
- Verify navigation buttons are fully visible
- Verify header height remains consistent

**Rollback Strategy**
- Git commit before changes: easy rollback if issues arise
- Revert commit: `git reset --hard HEAD~1`

## Open Questions

1. Should vertical padding also be made responsive for a more consistent experience? (Currently keeping fixed at 16px)