## ADDED Requirements

### Requirement: Feed items animate in on load
When feed items are loaded, they SHALL animate in with a staggered fly-in effect.

#### Scenario: Items stagger on initial load
- **WHEN** feeds are loaded and items are displayed
- **THEN** each item appears with a slight delay from the previous item, creating a cascade effect

#### Scenario: Entry animation uses Svelte fly transition
- **WHEN** items are loaded
- **THEN** the animation uses Svelte's built-in fly transition with upward motion

### Requirement: Entry animation timing
The entry animation SHALL use timing that creates visual interest without being distracting.

#### Scenario: Animation delay per item
- **WHEN** items are loaded
- **THEN** each subsequent item is delayed by approximately 50ms from the previous item

#### Scenario: Animation duration
- **WHEN** an item begins its entry animation
- **THEN** the animation completes in approximately 300ms

### Requirement: Entry animation applies to timeline view
The entry animation SHALL also apply when viewing the timeline view.

#### Scenario: Timeline items animate on load
- **WHEN** timeline page loads and items are displayed
- **THEN** items animate in with the same staggered effect as the feeds view
