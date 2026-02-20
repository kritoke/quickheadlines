## ADDED Requirements

### Requirement: Keyboard Navigation
The FeedTabs component SHALL provide full keyboard navigation per WAI-ARIA tabs pattern.

#### Scenario: Arrow keys navigate between tabs
- **WHEN** the user presses Left/Right arrow keys while focus is on a tab
- **THEN** focus SHALL move to the previous/next tab
- **AND** the active tab SHALL NOT change until Enter/Space is pressed

#### Scenario: Home/End keys jump to first/last tab
- **WHEN** the user presses Home or End while focused on a tab
- **THEN** focus SHALL move to the first or last tab respectively

### Requirement: ARIA Compliance
The FeedTabs component SHALL include proper ARIA attributes.

#### Scenario: Tabs have correct ARIA roles
- **WHEN** the component renders
- **THEN** the tab list SHALL have `role="tablist"`
- **AND** each tab trigger SHALL have `role="tab"`
- **AND** each tab SHALL have `aria-selected` reflecting its active state

### Requirement: Scroll to Active
The FeedTabs component SHALL scroll to center the active tab when it changes.

#### Scenario: Active tab scrolls into view
- **WHEN** the user changes to a different tab
- **THEN** the tab bar SHALL smoothly scroll to center the newly active tab
