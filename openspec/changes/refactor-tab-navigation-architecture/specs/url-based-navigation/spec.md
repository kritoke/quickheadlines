## ADDED Requirements

### Requirement: URL as single source of truth for tab state
The application SHALL use only URL search parameters as the authoritative source of truth for current tab selection. All components SHALL read the current tab directly from `$page.url.searchParams.get('tab')` and SHALL NOT maintain intermediate tab state in stores or component state.

#### Scenario: Feed page reads tab from URL
- **WHEN** user navigates to `/?tab=Tech`
- **THEN** feed page displays Tech tab content
- **AND** all navigation and UI components read tab directly from URL parameter
- **AND** no intermediate state stores are used

#### Scenario: Timeline page reads tab from URL
- **WHEN** user navigates to `/timeline?tab=Science`  
- **THEN** timeline page displays Science tab content
- **AND** all navigation and UI components read tab directly from URL parameter
- **AND** no intermediate state stores are used

### Requirement: Elimination of intermediate tab state
The application SHALL NOT use `feedState.activeTab` or `navigationStore.feedsTab` for tab state management. These state stores SHALL be removed from the codebase entirely.

#### Scenario: Removed activeTab property
- **WHEN** code references `feedState.activeTab`
- **THEN** compilation fails due to property not existing
- **AND** developers must use URL parameters instead

#### Scenario: Removed feedsTab property  
- **WHEN** code references `navigationStore.feedsTab`
- **THEN** compilation fails due to property not existing
- **AND** developers must use URL parameters instead