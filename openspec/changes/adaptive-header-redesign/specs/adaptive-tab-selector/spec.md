## ADDED Requirements

### Requirement: Tab selector shall display inline tabs on desktop
On desktop viewports (≥768px), the tab selector SHALL display up to 5 tabs inline as text links, with an underline indicator for the active tab.

#### Scenario: Desktop shows inline tabs
- **WHEN** viewport width is ≥768px AND there are 5 or fewer tabs
- **THEN** all tabs display inline as text links in a single row

#### Scenario: Desktop shows inline tabs with overflow
- **WHEN** viewport width is ≥768px AND there are more than 5 tabs
- **THEN** first 5 tabs display inline, remaining tabs accessible via "More" dropdown button

#### Scenario: Active tab shows underline indicator
- **WHEN** a tab is active
- **THEN** a 2px blue underline indicator appears below the tab text

### Requirement: Tab selector shall show dropdown for overflow tabs
When tabs exceed the inline limit, a "More" dropdown button SHALL appear. Clicking it SHALL reveal a dropdown menu listing overflow tabs.

#### Scenario: More button reveals dropdown
- **WHEN** user clicks "More" button
- **THEN** a dropdown menu appears below the button listing all overflow tabs

#### Scenario: Selecting overflow tab closes dropdown
- **WHEN** user clicks a tab in the overflow dropdown
- **THEN** the dropdown closes AND the selected tab becomes active

#### Scenario: Clicking outside dropdown closes it
- **WHEN** user clicks outside an open dropdown
- **THEN** the dropdown closes

### Requirement: Tab selector shall emit tab change events
When a user selects a tab, the tab selector SHALL emit an event with the tab name to enable URL updates and content filtering.

#### Scenario: Tab selection emits event
- **WHEN** user clicks any tab (inline or overflow)
- **THEN** the component emits an `onTabChange` callback with the tab name as argument

### Requirement: Tab selector shall be keyboard accessible
Users SHALL be able to navigate and select tabs using keyboard controls.

#### Scenario: Arrow keys navigate between inline tabs
- **WHEN** focus is on a tab AND user presses Left or Right arrow
- **THEN** focus moves to adjacent tab

#### Scenario: Enter key selects focused tab
- **WHEN** focus is on a tab AND user presses Enter
- **THEN** the tab becomes active AND the onTabChange callback fires

### Requirement: Tab selector shall adapt display for mobile
On mobile viewports (<768px), the tab selector SHALL display as a dropdown button that opens a sheet when tapped.

#### Scenario: Mobile shows dropdown button
- **WHEN** viewport width is <768px
- **THEN** tabs display as a single "Category: [Active]" button instead of inline tabs

#### Scenario: Mobile dropdown button shows active tab
- **WHEN** viewport width is <768px
- **THEN** the button displays the currently active tab name with a chevron indicator
