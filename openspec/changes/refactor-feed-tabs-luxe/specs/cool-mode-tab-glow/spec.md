## ADDED Requirements

### Requirement: Tab Glow Effect
The active tab SHALL display a subtle glow when cursorTrail mode is enabled.

#### Scenario: Glow appears in cursorTrail mode
- **WHEN** themeState.cursorTrail is true
- **AND** a tab is active
- **THEN** the active pill SHALL have box-shadow of `0 0 15px -3px rgba(150,173,141,0.4)`
- **AND** the border SHALL use accent color at 40% opacity

#### Scenario: No glow when cursorTrail disabled
- **WHEN** themeState.cursorTrail is false
- **THEN** the active pill SHALL NOT have the glow effect

### Requirement: Accent Color
The glow effect SHALL use the Wasabi Green accent color.

#### Scenario: Consistent accent color
- **WHEN** rendering any accent-colored element
- **THEN** the color SHALL be #96ad8d (Wasabi Green)
