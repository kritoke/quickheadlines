## ADDED Requirements

### Requirement: Centralized navigation service
The application SHALL provide a `NavigationService` class that handles all view switching and URL construction logic. All navigation operations SHALL be performed through this service rather than scattered across components.

#### Scenario: Navigate to timeline view
- **WHEN** user clicks timeline button from feed page
- **THEN** NavigationService constructs URL `/timeline?tab=<current-tab>`
- **AND** navigates to constructed URL
- **AND** ensures current tab is preserved from URL parameter

#### Scenario: Navigate to feed view  
- **WHEN** user clicks feed button from timeline page
- **THEN** NavigationService constructs URL `/?tab=<current-tab>`
- **AND** navigates to constructed URL  
- **AND** ensures current tab is preserved from URL parameter

### Requirement: Consistent URL construction
The NavigationService SHALL construct URLs consistently using the same logic for tab parameter encoding and path construction.

#### Scenario: Special character tab names
- **WHEN** current tab is "AI & ML"
- **THEN** NavigationService constructs properly encoded URL like `/?tab=AI%20%26%20ML`
- **AND** timeline navigation constructs `/timeline?tab=AI%20%26%20ML`
- **AND** both URLs work correctly with backend API

#### Scenario: Global timeline navigation
- **WHEN** current tab is "all" 
- **THEN** NavigationService constructs `/timeline` (without tab parameter)
- **AND** feed navigation constructs `/` (without tab parameter)