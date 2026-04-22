## Requirement: Keyboard Navigation
The FeedTabs component SHALL provide full keyboard navigation per WAI-ARIA tabs pattern.

### Scenario: Arrow keys navigate between tabs
- **WHEN** the user presses Left/Right arrow keys while focus is on a tab
- **THEN** focus SHALL move to the previous/next tab

### Requirement: ARIA Compliance
The FeedTabs component SHALL include proper ARIA attributes.

### Scenario: Tabs have correct ARIA roles
- **WHEN** the component renders
- **THEN** the tab list SHALL have `role="tablist"`
- **AND** each tab trigger SHALL have `role="tab"`
- **AND** each tab SHALL have `aria-selected` reflecting its active state
