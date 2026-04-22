## ADDED Requirements

### Requirement: Three-way view navigation
The system SHALL provide navigation controls that allow users to switch between three distinct view modes: Feed Box View, Tab Timeline View, and Global Timeline View.

#### Scenario: Navigation displays three view options
- **WHEN** user views the main interface
- **THEN** navigation shows three distinct view options with appropriate icons
- **AND** the currently active view is clearly indicated

### Requirement: Feed box view icon and labeling
The feed box view SHALL be represented with a box/package icon (📦) and maintain its existing functionality of displaying feeds organized by source.

#### Scenario: Feed box view displays correct icon
- **WHEN** user views the navigation controls
- **THEN** the feed box view option shows a 📦 icon
- **AND** displays feeds grouped by their configured source

### Requirement: Navigation layout positioning
The navigation controls SHALL be positioned with the Global Timeline icon to the left of the view toggle but to the right of the search functionality.

#### Scenario: Correct navigation layout
- **WHEN** user views the interface on desktop
- **THEN** the layout order is: Search → Global Timeline (🌐) → Feed Box (📦) ↔ Tab Timeline (⏱️)
- **AND** the interface remains responsive on mobile devices

### Requirement: URL-based routing with view persistence
The system SHALL use URL parameters to maintain view state and enable bookmarkable URLs, preserving both the current view mode and selected tab.

#### Scenario: URL reflects current view and tab
- **WHEN** user switches to global timeline while on "tech" tab
- **THEN** URL updates to include both view and tab parameters (e.g., /timeline?view=global&tab=tech)
- **AND** refreshing the page maintains the same view and tab selection

### Requirement: Seamless view transitions
The system SHALL provide smooth transitions between views while preserving scroll position and loaded content where possible.

#### Scenario: View switching maintains context
- **WHEN** user switches between views
- **THEN** the transition is smooth without full page reloads
- **AND** scroll position is preserved when returning to a previously viewed state