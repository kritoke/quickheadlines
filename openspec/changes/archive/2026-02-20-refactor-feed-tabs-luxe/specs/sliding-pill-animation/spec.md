## Requirement: Sliding Pill Animation

### Scenario: Pill animates on tab change
- **WHEN** the user selects a different tab
- **THEN** the active pill background SHALL animate using Svelte's fly transition
- **WITH** duration of 300ms and cubicOut easing

### Scenario: View Transitions API support
- **WHEN** the browser supports View Transitions API
- **THEN** the pill SHALL use view-transition-name: tab-pill
- **AND** cross-tab animations SHALL be smooth

### Scenario: Light mode pill styling
- **WHEN** in light mode
- **THEN** the pill SHALL have white background
- **AND** subtle border using slate-200

### Scenario: Dark mode pill styling
- **WHEN** in dark mode
- **THEN** the pill SHALL have slate-700 background
- **AND** subtle border using slate-600
