## ADDED Requirements

### Requirement: Shared app state for tabs
The system SHALL provide a shared `appState` store that maintains tab state accessible by both feed and timeline views.

#### Scenario: AppState provides tab list
- **WHEN** the user navigates between feed and timeline views
- **THEN** both views access the same tab list from `appState`
- **AND** no separate HTTP requests are made just to fetch tabs

#### Scenario: Active tab is synchronized
- **WHEN** user selects a tab in feed view
- **AND** then navigates to timeline view
- **THEN** timeline view displays the same selected tab
- **AND** the URL parameter reflects the selected tab

#### Scenario: Tab changes update both views
- **WHEN** tabs are modified (added/removed) in the backend
- **AND** the next refresh occurs
- **THEN** both feed and timeline views show the updated tab list

## MODIFIED Requirements

### Requirement: Mobile tab bar on feed page
FROM: openspec/specs/mobile-tab-navigation/spec.md - existing requirement for feed page

The mobile tab bar on the feed page SHALL remain functional with existing frosted glass, shadow, and theme-aware behaviors.

#### Scenario: Feed page mobile tabs work as before
- **WHEN** user is on feed page on mobile
- **THEN** the tab selector component appears at the bottom
- **AND** tapping reveals a bottom sheet with all tabs

### Requirement: Mobile tab bar on timeline page
The system SHALL display a mobile tab selector on the timeline page that functions identically to the feed page.

#### Scenario: Timeline page shows mobile tab selector
- **WHEN** user navigates to /timeline on a mobile device (viewport < 768px)
- **THEN** a tab selector appears below the header
- **AND** it displays the current tab name

#### Scenario: Tapping timeline tab selector opens bottom sheet
- **WHEN** user taps the tab area on timeline mobile view
- **THEN** a bottom sheet appears showing all available tabs

#### Scenario: Tab selection updates timeline
- **WHEN** user selects a different tab from the timeline bottom sheet
- **THEN** the timeline reloads showing items from only that tab
- **AND** the URL updates to include the tab parameter