## ADDED Requirements

### Requirement: Focus-visible indicators on all interactive header elements
All interactive buttons in the header (search, view switch, effects toggle, theme picker trigger, layout picker trigger) SHALL display a visible focus ring when focused via keyboard navigation.

#### Scenario: Search button shows focus ring
- **WHEN** user tabs to the search button
- **THEN** a visible focus ring appears around the button
- **AND** the ring color is theme-aware

#### Scenario: Theme picker trigger shows focus ring
- **WHEN** user tabs to the theme picker trigger
- **THEN** a visible focus ring appears
- **AND** the ring does not appear on mouse click (only keyboard focus)

#### Scenario: Effects toggle shows focus ring
- **WHEN** user tabs to the effects toggle button
- **THEN** a visible focus ring appears

#### Scenario: View switch button shows focus ring
- **WHEN** user tabs to the view switch button
- **THEN** a visible focus ring appears
