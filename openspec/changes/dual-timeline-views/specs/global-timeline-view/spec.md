## ADDED Requirements

### Requirement: Global timeline view displays all chronological items
The system SHALL provide a global timeline view that displays all items from all configured feeds in chronological order (most recent first), regardless of current tab selection.

#### Scenario: Global timeline shows all items
- **WHEN** user navigates to the global timeline view
- **THEN** the timeline displays items from all feeds across all tabs
- **AND** items are sorted by publication date in descending order
- **AND** current tab selection does not affect the displayed content

### Requirement: Global timeline supports infinite scroll
The global timeline view SHALL support infinite scroll pagination for loading additional items beyond the initial display limit.

#### Scenario: Infinite scroll loads more items globally
- **WHEN** user scrolls to the bottom of the global timeline
- **THEN** the system loads additional items from all feeds
- **AND** maintains chronological ordering across all loaded items

### Requirement: Global timeline applies clustering
The global timeline view SHALL apply clustering logic to group similar articles across all feeds.

#### Scenario: Clustering works globally
- **WHEN** multiple similar articles exist across different feed tabs
- **THEN** they are clustered together in the global timeline view
- **AND** clustering operates across all available feeds

### Requirement: Global timeline icon and labeling
The global timeline view SHALL be represented with a globe icon (🌐) and labeled as "Global Timeline" in the navigation interface.

#### Scenario: Correct icon and label displayed
- **WHEN** user views the navigation controls
- **THEN** the global timeline option shows a 🌐 icon
- **AND** is labeled as "Global Timeline"