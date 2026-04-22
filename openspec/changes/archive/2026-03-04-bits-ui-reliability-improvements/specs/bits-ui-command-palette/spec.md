## ADDED Requirements

### Requirement: Command Palette Activation
The system SHALL provide a command palette that can be activated via keyboard shortcut.

#### Scenario: Open command palette with keyboard shortcut
- **WHEN** user presses Cmd+K (Mac) or Ctrl+K (Windows/Linux)
- **AND** no input field is currently focused
- **THEN** the command palette SHALL open

#### Scenario: Do not activate when input focused
- **WHEN** user presses Cmd+K or Ctrl+K
- **AND** an input field is currently focused
- **THEN** the command palette SHALL NOT open
- **AND** normal keyboard input SHALL continue

#### Scenario: Close command palette with Escape
- **WHEN** the command palette is open
- **AND** user presses Escape
- **THEN** the command palette SHALL close
- **AND** focus SHALL return to the previously focused element

### Requirement: Feed Search Functionality
The command palette SHALL provide fuzzy search for feed names.

#### Scenario: Search feeds by name
- **WHEN** user types in the search input
- **AND** there are feeds matching the query
- **THEN** the matching feeds SHALL be displayed in the results list
- **AND** results SHALL update as the user types

#### Scenario: No matching feeds
- **WHEN** user types a search query
- **AND** no feeds match the query
- **THEN** a "No results found" message SHALL be displayed

#### Scenario: Navigate results with arrow keys
- **WHEN** command palette is open with results
- **AND** user presses Down Arrow
- **THEN** the next result SHALL be highlighted
- **AND** pressing Up Arrow SHALL highlight the previous result

### Requirement: Select Feed from Results
The command palette SHALL allow selecting a feed from the results.

#### Scenario: Select feed with Enter
- **WHEN** a result is highlighted
- **AND** user presses Enter
- **THEN** the selected feed SHALL be navigated to
- **AND** the command palette SHALL close

#### Scenario: Select feed with mouse click
- **WHEN** user clicks on a result item
- **THEN** the selected feed SHALL be navigated to
- **AND** the command palette SHALL close

### Requirement: Command Palette Accessibility
The command palette SHALL be accessible to users with disabilities.

#### Scenario: Screen reader announces search input
- **WHEN** command palette opens
- **AND** a screen reader is active
- **THEN** the search input SHALL be labeled
- **AND** results count SHALL be announced

#### Scenario: Keyboard navigation is fully supported
- **WHEN** command palette is open
- **AND** user navigates using only keyboard
- **THEN** all functionality SHALL be accessible
- **AND** Tab/Shift+Tab SHALL move through all interactive elements
