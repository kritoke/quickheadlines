## ADDED Requirements

### Requirement: Empty timeline feedback
The application SHALL provide clear user feedback when a timeline contains no items, rather than displaying a blank page.

#### Scenario: Timeline has no items
- **WHEN** timeline API returns empty items array with no error
- **THEN** user sees "No items found for this tab. Try refreshing or checking back later." message
- **AND** loading spinner is not displayed after initial load completes

### Requirement: Loading state handling
The application SHALL display appropriate loading states during timeline data fetch operations.

#### Scenario: Initial timeline load
- **WHEN** user navigates to timeline view and data is being fetched
- **THEN** user sees "Loading timeline..." with spinner
- **AND** this state persists until data load completes or fails

#### Scenario: Timeline refresh with existing items
- **WHEN** user triggers timeline refresh while existing items are displayed
- **THEN** user sees "Refreshing..." indicator in sticky header
- **AND** existing items remain visible during refresh

### Requirement: Error state handling  
The application SHALL display meaningful error messages when timeline data fetch fails.

#### Scenario: Timeline API returns error
- **WHEN** timeline API request fails with error
- **THEN** user sees error message with "Retry" button
- **AND** clicking retry attempts to reload timeline data

#### Scenario: Empty timeline with error
- **WHEN** timeline returns error and has no previously loaded items  
- **THEN** user sees error message with "Retry" button
- **AND** no timeline items are displayed