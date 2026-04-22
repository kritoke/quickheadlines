## ADDED Requirements

### Requirement: Tab timeline view displays chronological items
The system SHALL provide a timeline view that displays only items from the currently selected feed tab in chronological order (most recent first).

#### Scenario: Timeline loads with current tab items only
- **WHEN** user navigates to the tab timeline view while on a specific feed tab
- **THEN** the timeline displays only items from feeds belonging to that tab
- **AND** items are sorted by publication date in descending order

#### Scenario: Timeline updates when tab changes
- **WHEN** user switches to a different feed tab while in tab timeline view
- **THEN** the timeline automatically updates to show items from the new tab only
- **AND** maintains chronological ordering

### Requirement: Tab timeline supports infinite scroll
The tab timeline view SHALL support infinite scroll pagination for loading additional items beyond the initial display limit.

#### Scenario: Infinite scroll loads more items
- **WHEN** user scrolls to the bottom of the tab timeline
- **THEN** the system loads additional items from the same tab
- **AND** maintains chronological ordering across all loaded items

### Requirement: Tab timeline applies clustering
The tab timeline view SHALL apply the same clustering logic as the global timeline to group similar articles within the tab scope.

#### Scenario: Clustering works within tab scope
- **WHEN** multiple similar articles exist within the same feed tab
- **THEN** they are clustered together in the tab timeline view
- **AND** clustering respects the tab boundary (no cross-tab clustering)

### Requirement: Tab timeline icon and labeling
The tab timeline view SHALL be represented with a clock/stopwatch icon (⏱️) and labeled as "Timeline" in the navigation interface.

#### Scenario: Correct icon and label displayed
- **WHEN** user views the navigation controls
- **THEN** the tab timeline option shows a ⏱️ icon
- **AND** is labeled as "Timeline"