# Spec: feed-card-styling

Capability: feed-card-styling

Purpose
- Define styling requirements for feed cards on the home page, ensuring consistent appearance and proper dark mode support.

Background
- Proposal: Add CSS styling for feed cards. Design: Consistent padding, header area, title typography, dark mode support, hover states, favicon alignment.

Requirements
1) Card Padding
   - Feed cards SHALL have consistent padding of 12px on all sides.
   - Padding is consistent across all cards.

2) Header Area Styling
   - Feed card headers SHALL have consistent height and alignment.
   - Header height is fixed at 44px minimum.
   - Content is vertically centered.
   - Favicon is 18x18px with 8px right margin.

3) Title Typography
   - Feed titles SHALL use consistent font sizing and weight.
   - Font size is 1.1rem (17.6px).
   - Font weight is 700 (bold).
   - Line height is 1.2.

4) Dark Mode Text Contrast
   - Text colors SHALL have sufficient contrast in dark mode.
   - Text on light backgrounds has color `#1f2937`.
   - Text on dark backgrounds has color `#f8fafc`.
   - Contrast ratio meets WCAG AA standards (4.5:1).

5) Hover States
   - Interactive elements SHALL provide visual feedback on hover.
   - Hovering over a feed title link changes text color.
   - Cursor changes to pointer.

6) Favicon Alignment
   - Favicons SHALL be consistently aligned across all cards.
   - All favicons are vertically centered.
   - Favicons have consistent 8px right margin.
   - Favicons maintain 18x18px dimensions.

Acceptance criteria
- Feed cards have consistent padding and layout.
- Titles are readable with proper font sizing.
- Dark mode has proper contrast.
- Hover states provide feedback.
- Favicons are aligned consistently.
