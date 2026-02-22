# Spec: desktop-header-consistency

Capability: desktop-header-consistency

Purpose
- Define requirements for consistent header styling, layout, and spacing across all views (Home, Timeline) on desktop breakpoints. This ensures a unified user experience regardless of which view is active.

Background
- Proposal: fix-timeline-header-and-clustering addresses inconsistent header styling between views and improved visual breathing room. Design: outlines CSS class-based approach for consistent styling.

Requirements
1) Shared header class application
   - The site header component SHALL apply a CSS class `.qh-site-header` to the root container element on all views (Home, Timeline).
   - The `.qh-site-header` class SHALL be applied consistently using the same Elm `htmlAttribute` mechanism across all views.

   #### Scenario: Header class applied on Home view
   - **WHEN** the Home view is rendered
   - **THEN** the header container element SHALL have the `.qh-site-header` CSS class applied

   #### Scenario: Header class applied on Timeline view
   - **WHEN** the Timeline view is rendered
   - **THEN** the header container element SHALL have the `.qh-site-header` CSS class applied

2) Desktop horizontal padding
   - The site header SHALL have horizontal padding of 24px on each side on desktop breakpoints (>=640px).
   - The horizontal padding MUST be applied through the `.qh-site-header` class, not through inline Elm styles.

   #### Scenario: Desktop header padding applied
   - **WHEN** the viewport width is 640px or wider
   - **THEN** the site header SHALL have 24px of horizontal padding on both left and right sides

   #### Scenario: Mobile padding unchanged
   - **WHEN** the viewport width is less than 640px
   - **THEN** the site header SHALL retain existing mobile padding behavior (no changes to mobile padding)

3) Header layout consistency
   - The site header SHALL maintain identical layout structure across all views on desktop breakpoints.
   - The header SHALL render the brand section (logo + text), navigation icons, and actions (theme toggle) in the same order and alignment on all views.

   #### Scenario: Header layout identical on Home
   - **WHEN** the Home view header is rendered on desktop
   - **THEN** the brand section SHALL be on the left, navigation icons in the center, and actions on the right

   #### Scenario: Header layout identical on Timeline
   - **WHEN** the Timeline view header is rendered on desktop
   - **THEN** the brand section SHALL be on the left, navigation icons in the center, and actions on the right

4) Theme compatibility
   - The `.qh-site-header` class styling SHALL work correctly in both light and dark themes.
   - The header background, text colors, and borders MUST respect theme variables defined in CSS.

   #### Scenario: Header renders correctly in light theme
   - **WHEN** the application is in light mode on desktop
   - **THEN** the header SHALL use light theme colors for background, text, and borders

   #### Scenario: Header renders correctly in dark theme
   - **WHEN** the application is in dark mode on desktop
   - **THEN** the header SHALL use dark theme colors for background, text, and borders

5) Responsive breakpoint handling
   - The `.qh-site-header` class SHALL apply desktop-specific styling only on breakpoints >=640px using a CSS media query.
   - Mobile-specific styling (<640px) MUST NOT be affected by `.qh-site-header` desktop styles.

   #### Scenario: Desktop styles apply above breakpoint
   - **WHEN** the viewport width is 640px or wider
   - **THEN** the `.qh-site-header` class SHALL apply desktop horizontal padding and layout styles

   #### Scenario: Desktop styles do not apply below breakpoint
   - **WHEN** the viewport width is 639px or narrower
   - **THEN** the `.qh-site-header` class SHALL NOT apply desktop-specific horizontal padding

Acceptance criteria
- Visual: Header styling is visually identical between Home and Timeline views on desktop breakpoints
- Consistency: Both views use the same `.qh-site-header` CSS class
- Responsiveness: Mobile header behavior remains unchanged (existing tests pass)
- Theme: Header renders correctly in both light and dark themes

Testing
- Manual visual comparison of Home vs Timeline headers on desktop breakpoints (640px, 768px, 1024px, 1440px)
- Verify CSS class presence using browser dev tools on both views
- Test light/dark theme switching on both views
- Responsive testing at breakpoint boundaries (639px vs 640px)

Output path
- `openspec/changes/fix-timeline-header-and-clustering/specs/desktop-header-consistency/spec.md`
