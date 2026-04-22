## ADDED Requirements

### Requirement: Pure presentational AppHeader
The AppHeader component SHALL be purely presentational with no navigation logic or state management. All required data SHALL be passed as props from parent pages.

#### Scenario: AppHeader receives all necessary props
- **WHEN** AppHeader is rendered
- **THEN** it receives `tabs`, `currentTab`, `currentView`, and `onTabChange` as props
- **AND** it does not access `$page` store or perform any navigation logic
- **AND** it delegates all user interactions to provided callback props

### Requirement: No internal state management
The AppHeader component SHALL NOT maintain any internal state related to tabs, views, or navigation. All state management SHALL be handled by parent pages or the NavigationService.

#### Scenario: Tab selection updates
- **WHEN** user selects a different tab in AppHeader
- **THEN** AppHeader calls the `onTabChange` prop callback
- **AND** does not update its own state or perform navigation
- **AND** parent page handles the tab change through NavigationService

#### Scenario: View switching
- **WHEN** user clicks view switch button in AppHeader  
- **THEN** AppHeader calls provided navigation callback
- **AND** does not construct URLs or perform goto operations
- **AND** parent page or NavigationService handles actual navigation