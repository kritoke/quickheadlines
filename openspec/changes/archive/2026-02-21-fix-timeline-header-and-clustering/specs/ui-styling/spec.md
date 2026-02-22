## ADDED Requirements

### Requirement: Desktop header spacing
The site header SHALL have horizontal padding of 24px on each side on desktop breakpoints (>=640px). The header container SHALL use a shared CSS class `.qh-site-header` to ensure consistent padding application across all views.

#### Scenario: Desktop header has 24px horizontal padding
- **WHEN** the viewport width is 640px or wider
- **THEN** the site header container SHALL have 24px padding on the left and right sides

#### Scenario: Header class applied consistently across views
- **WHEN** any view (Home, Timeline) is rendered on desktop
- **THEN** the site header container SHALL have the `.qh-site-header` CSS class applied
- **AND** the horizontal padding SHALL be 24px on both sides

### Requirement: Header layout consistency across views
The site header SHALL maintain identical layout structure (brand, navigation, actions) and visual appearance across all views on desktop breakpoints. The `.qh-site-header` class SHALL ensure styling consistency.

#### Scenario: Header layout structure matches on all desktop views
- **WHEN** the Home view header is rendered on desktop
- **WHEN** the Timeline view header is rendered on desktop
- **THEN** both headers SHALL have the same layout order (brand left, navigation center, actions right)
- **AND** both headers SHALL use identical spacing between elements
- **AND** both headers SHALL apply the same background, text color, and border styles
