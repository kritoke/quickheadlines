## Context

The timeline page uses a responsive layout that works well on desktop and tablet sizes, but on very small screens (< 480px width), fixed-width elements and padding create excessive whitespace to the right of the content. This causes the actual content to be squeezed into a very narrow column, making text appear small and the layout unbalanced.

Current layout structure:
- Main container with horizontal padding (currently responsive: 40px desktop, 16px mobile, 8px very narrow)
- Time column with fixed 85px width
- Content area with fixed left padding of 105px for expanded clusters
- Single column layout on small screens

The problem occurs when viewport width approaches the sum of fixed widths (85px + 105px = 190px) plus padding, leaving minimal space for actual content.

## Goals / Non-Goals

**Goals:**
- Reduce excessive horizontal spacing on screens < 480px width
- Make time column width responsive to viewport size
- Make cluster item padding responsive to prevent content squeeze
- Maintain readable text size and touch targets on mobile
- Preserve existing desktop layout behavior

**Non-Goals:**
- Change the overall timeline information architecture
- Modify cluster expansion/collapse behavior
- Alter the single-column layout approach on mobile
- Add new breakpoints or major layout restructuring

## Decisions

**Responsive Time Column Width**
- Use CSS media queries to reduce time column from 85px to 60px on screens < 480px
- Decision rationale: 60px maintains readability of time stamps while freeing up 25px of horizontal space
- Alternatives considered: Fluid width (percentage-based) - rejected because time stamps need consistent width for alignment

**Responsive Cluster Padding**
- Reduce left padding for expanded clusters from 105px to 70px on screens < 480px
- Decision rationale: Balances with reduced time column width (60px + 70px = 130px vs original 190px)
- Alternative: Remove time column entirely on mobile - rejected to preserve chronological context

**CSS Implementation Approach**
- Extend existing media query structure in Timeline.elm
- Use CSS custom properties for consistent spacing values
- Decision rationale: Maintains existing responsive pattern, allows for easy maintenance
- Alternative: Inline styles in Elm - rejected for maintainability and consistency with existing codebase

## Risks / Trade-offs

**Content Density vs Readability**
- Risk: Reducing padding might make content feel cramped
- Mitigation: Test on actual devices, ensure minimum 16px margins maintained

**Breakpoint Edge Cases**
- Risk: Layout jarring at exact breakpoint transitions
- Mitigation: Test across range of screen sizes (400px-500px) during implementation

**Performance Impact**
- Risk: Additional CSS media queries could affect render performance
- Mitigation: Minimal queries (one new breakpoint), follows existing patterns