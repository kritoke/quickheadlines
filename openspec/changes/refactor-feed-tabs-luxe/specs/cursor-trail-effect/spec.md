## ADDED Requirements

### Requirement: Spring-Based Cursor Following
The CursorTrail component SHALL follow the mouse cursor with physics-based spring animation.

#### Scenario: Dots follow cursor with lag
- **WHEN** the user moves the mouse
- **THEN** the primary dot SHALL follow with a spring animation
- **AND** the aura dot SHALL follow with additional lag for trailing effect
- **USING** Svelte 5's `Spring` class with configurable stiffness and damping

### Requirement: Visual Design
The cursor trail SHALL consist of two layered dots.

#### Scenario: Primary dot renders
- **WHEN** the component is active
- **THEN** a small dot (8px radius) SHALL render at cursor position
- **AND** SHALL use the accent color (Wasabi Green #96ad8d)

#### Scenario: Aura dot renders with blur
- **WHEN** the component is active
- **THEN** a larger dot (40px radius) SHALL render behind the primary dot
- **AND** SHALL have `filter: blur(12px)` applied
- **AND** SHALL use the accent color at reduced opacity (30%)

### Requirement: Non-Interference
The cursor trail SHALL NOT interfere with page interactions.

#### Scenario: Pointer events pass through
- **WHEN** the cursor trail is active
- **THEN** both dots SHALL have `pointer-events: none`
- **AND** clicks SHALL pass through to underlying elements
- **AND** the container SHALL have `z-index: 9999` (below modals, above content)

### Requirement: Toggle Control
The cursor trail SHALL be toggleable from the header.

#### Scenario: Toggle button activates trail
- **WHEN** the user clicks the cursor toggle button in the header
- **THEN** `themeState.cursorTrail` SHALL toggle between true/false
- **AND** the state SHALL persist in localStorage as `quickheadlines-cursortrail`

#### Scenario: New icon replaces polka dots
- **WHEN** the header renders
- **THEN** the toggle button SHALL display a cursor/pointer icon
- **NOT** the polka dot circles icon
