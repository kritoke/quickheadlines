## ADDED Requirements

### Requirement: Cursor trail respects prefers-reduced-motion
The `Effects.svelte` cursor trail and click particles SHALL NOT render when the user's system has `prefers-reduced-motion: reduce` enabled.

#### Scenario: No cursor trail with reduced motion preference
- **WHEN** user has `prefers-reduced-motion: reduce` enabled in OS settings
- **AND** effects are toggled on in the app
- **THEN** no cursor trail `<div>` elements are rendered to the DOM
- **AND** no click particles are spawned on click

#### Scenario: Cursor trail works normally without reduced motion
- **WHEN** user does NOT have reduced motion preference
- **AND** effects are toggled on
- **THEN** cursor trail renders normally with spring physics
- **AND** click particles spawn on click

### Requirement: Border beam respects prefers-reduced-motion
The `BorderBeam.svelte` rotating conic gradient animation SHALL be disabled when `prefers-reduced-motion: reduce` is active.

#### Scenario: No rotation with reduced motion
- **WHEN** user has `prefers-reduced-motion: reduce` enabled
- **AND** a theme with border beam is active
- **THEN** the border beam element is either hidden or has `animation: none`
- **AND** no continuous rotation occurs

#### Scenario: Normal beam with no motion preference
- **WHEN** user does NOT have reduced motion preference
- **AND** cyberpunk theme is active
- **THEN** border beam rotates normally with configured duration

### Requirement: Item appear animation respects prefers-reduced-motion
The `.new-item` entrance animation in `app.css` SHALL be instant (no animation) when `prefers-reduced-motion: reduce` is active.

#### Scenario: Items appear instantly with reduced motion
- **WHEN** user has reduced motion preference
- **AND** new feed items load
- **THEN** items appear immediately without scale/translate animation
- **AND** no spring-like cubic-bezier motion occurs

### Requirement: Mobile tab sheet respects prefers-reduced-motion
The `MobileTabSheet.svelte` slide-up animation SHALL be instant when `prefers-reduced-motion: reduce` is active.

#### Scenario: Sheet appears instantly with reduced motion
- **WHEN** user has reduced motion preference
- **AND** mobile tab sheet opens
- **THEN** sheet appears at final position without slide-up transition
- **AND** backdrop appears immediately
