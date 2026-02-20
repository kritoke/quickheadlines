## ADDED Requirements

### Requirement: Sliding Pill Animation
The active tab indicator SHALL animate smoothly when switching tabs.

#### Scenario: Pill animates on tab change
- **WHEN** the user selects a different tab
- **THEN** the active pill background SHALL animate using Svelte's fly transition
- **WITH** duration of 300ms and cubicOut easing

#### Scenario: View Transitions API support
- **WHEN** the browser supports View Transitions API
- **THEN** the pill SHALL use view-transition-name: tab-pill
- **AND** cross-tab animations SHALL be smooth with 350ms duration

### Requirement: Pill Styling
The active pill SHALL have the luxe aesthetic.

#### Scenario: Light mode pill
- **WHEN** in light mode
- **THEN** the pill SHALL have white background
- **AND** subtle border using zinc-200
- **AND** light shadow

#### Scenario: Dark mode pill
- **WHEN** in dark mode
- **THEN** the pill SHALL have zinc-800 background
- **AND** subtle border using zinc-700/50
