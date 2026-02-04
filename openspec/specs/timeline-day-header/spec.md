# Spec: timeline-day-header

Capability: timeline-day-header

Purpose
- Define visual styling for timeline day headers, ensuring consistent appearance across light and dark modes.

Background
- Proposal: Style timeline day headers with background colors, borders, and proper padding. Design: Light/dark mode colors, consistent padding, bottom border.

Requirements
1) Day Header Background
   - Day headers SHALL use a subtle background color for visual hierarchy.
   - Light mode: background `#f1f5f9` (slate-100), text `#1e293b` (slate-800).
   - Dark mode: background `#1e2937` (slate-800), text `#f8fafc` (slate-50).

2) Day Header Padding
   - Day headers SHALL have consistent padding of 12px vertical and 16px horizontal.
   - Padding is 12px top and bottom.
   - Padding is 16px left and right.

3) Day Header Border
   - Day headers SHALL include a subtle bottom border for visual separation.
   - 1px border is displayed at the bottom.
   - Border color `#e2e8f0` in light mode.
   - Border color `#334155` in dark mode.

4) Date Text Styling
   - The date text SHALL be prominent with semi-bold weight.
   - Font weight is 600 (semi-bold).
   - Font size is 14px.
   - Text is uppercase for day names (e.g., "MONDAY").

5) Consistent with Feed Headers
   - Day headers SHALL share visual language with feed card headers.
   - Both use the same font family.
   - Both use consistent border radius (4px).
   - Both transition smoothly on theme change.

Acceptance criteria
- Day headers have proper background colors in both modes.
- Padding and borders are consistent.
- Date text is prominent and readable.
- Visual language is consistent with feed headers.
