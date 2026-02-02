## Context

The Timeline page header displays the page name with a favicon. Currently the favicon alignment is incorrect - it should appear to the left of the page name with proper spacing.

## Goals / Non-Goals

**Goals:**
- Position favicon to the left of the page name
- Ensure consistent spacing between favicon and text
- Maintain alignment across viewport sizes

**Non-Goals:**
- Changes to the Home page header (not in scope)
- Changes to favicon fetching or caching logic

## Decisions

1. **Row Layout with spacing**: Use Element.row with spacing to position favicon and text side-by-side
   - Alternative: Use align attributes on individual elements
   - Chosen: Row with spacing is more maintainable and consistent with other headers

2. **Fixed icon size**: Set favicon to 16x16px to match brand logo sizing
   - Ensures visual consistency with the main logo in the header

## Risks / Trade-offs

- Low risk: Simple layout change, no data or API changes
- Trade-off: Minimal - only affects visual presentation
