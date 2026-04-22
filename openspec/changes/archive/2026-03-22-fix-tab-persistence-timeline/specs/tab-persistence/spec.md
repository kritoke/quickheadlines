## ADDED Requirements

### Requirement: URL as single source of truth
The application SHALL use only URL parameters as the authoritative source of truth for current tab selection. All components SHALL read the current tab directly from the URL rather than maintaining separate state variables.

#### Scenario: Feed page reads tab from URL
- **WHEN** user navigates to /?tab=Tech
- **THEN** feed page displays Tech tab content
- **AND** all navigation components read tab directly from URL parameter

#### Scenario: Timeline page reads tab from URL  
- **WHEN** user navigates to /timeline?tab=Science
- **THEN** timeline page displays Science tab content
- **AND** all navigation components read tab directly from URL parameter

### Requirement: Consistent view switching
The application SHALL maintain tab context when switching between feed view and timeline view. Navigation between views SHALL preserve the current tab selection.

#### Scenario: Switch from feed to timeline
- **WHEN** user is on /?tab=AI%20%26%20ML and clicks timeline button
- **THEN** user is navigated to /timeline?tab=AI%20%26%20ML
- **AND** timeline displays AI & ML content

#### Scenario: Switch from timeline to feed
- **WHEN** user is on /timeline?tab=Dev and clicks feed button  
- **THEN** user is navigated to /?tab=Dev
- **AND** feed page displays Dev tab content

### Requirement: Special character handling
The application SHALL properly handle tab names containing special characters (spaces, ampersands, etc.) in URLs without breaking navigation or causing encoding issues.

#### Scenario: Tab with ampersand works correctly
- **WHEN** user selects "AI & ML" tab
- **THEN** URL shows proper encoding as /?tab=AI%20%26%20ML
- **AND** navigation between views works correctly
- **AND** API requests receive properly decoded tab name

#### Scenario: Tab with spaces works correctly
- **WHEN** user selects "3D Printing" tab  
- **THEN** URL shows proper encoding as /?tab=3D%20Printing
- **AND** navigation between views works correctly